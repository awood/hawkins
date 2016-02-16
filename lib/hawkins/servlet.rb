require "webrick"

module Hawkins
  module Commands
    class LiveServe
      class SkipAnalyzer
        BAD_USER_AGENTS = [ %r{MSIE} ]

        def self.skip_processing?(req, res, options)
          new(req, res, options).skip_processing?
        end

        def initialize(req, res, options)
          @options = options
          @req = req
          @res = res
        end

        def skip_processing?
          !html? || chunked? || inline? || ignored? || bad_browser?
        end

        def chunked?
          @res['Transfer-Encoding'] == 'chunked'
        end

        def inline?
          @res['Content-Disposition'] =~ %r{^inline}
        end

        def ignored?
          path = @req.query_string.nil? ? @req.path_info : "#{@req.path_info}?#{@req.query_string}"
          @options["ignore"] and @options["ignore"].any? { |filter| path[filter] }
        end

        def bad_browser?
          BAD_USER_AGENTS.any? { |pattern| @req['User-Agent'] =~ pattern }
        end

        def html?
          @res['Content-Type'] =~ %r{text/html}
        end
      end

      class BodyProcessor
        LIVERELOAD_JS_PATH = '/__livereload/livereload.js'
        HEAD_TAG_REGEX = /<head>|<head[^(er)][^<]*>/
        LIVERELOAD_PORT = 35729

        attr_reader :content_length, :new_body, :livereload_added

        def initialize(body, options)
          @body = body
          @options = options
          @options["reload_port"] ||= LIVERELOAD_PORT

          @processed = false
        end

        def with_swf?
          @options["swf"]
        end

        def processed?
          @processed
        end

        def process!
          @new_body = []
          begin
            @body.each { |line| @new_body << line.to_s }
          ensure
            #@body will be a File object
            @body.close
          end

          @content_length = 0
          @livereload_added = false

          @new_body.each do |line|
            if !@livereload_added && line['<head']
              line.gsub!(HEAD_TAG_REGEX) { |match| %{#{match}#{template.result(binding)}} }

              @livereload_added = true
            end

            @content_length += line.bytesize
            @processed = true
          end
          @new_body = @new_body.join
        end

        def host_to_use
          (@options["host"] || 'localhost').gsub(%r{:.*}, '')
        end

        def template
          template = <<-TEMPLATE
          <% if with_swf? %>
            <script type="text/javascript">
              WEB_SOCKET_SWF_LOCATION = "/__livereload/WebSocketMain.swf";
              WEB_SOCKET_FORCE_FLASH = false;
            </script>
            <script type="text/javascript" src="<%= @options["baseurl"] %>/__livereload/swfobject.js"></script>
            <script type="text/javascript" src="<%= @options["baseurl"] %>/__livereload/web_socket.js"></script>
          <% end %>
          <script type="text/javascript">
            RACK_LIVERELOAD_PORT = <%= @options["reload_port"] %>;
          </script>
          <script type="text/javascript" src="<%= livereload_source %>"></script>
          TEMPLATE
          ERB.new(template)
        end

        def livereload_source
          src = "#{@options['baseurl']}#{LIVERELOAD_JS_PATH.dup}?host=#{host_to_use}"
          src << "&amp;mindelay=#{@options["min_delay"]}" if @options["min_delay"]
          src << "&amp;maxdelay=#{@options["max_delay"]}" if @options["max_delay"]
          src << "&amp;port=#{@options["reload_port"]}" if @options["reload_port"]
          src
        end
      end

      class Servlet < WEBrick::HTTPServlet::FileHandler
        DEFAULTS = {
          "Cache-Control" => "private, max-age=0, proxy-revalidate, " \
            "no-store, no-cache, must-revalidate"
        }

        def initialize(server, root, callbacks)
          # So we can access them easily.
          @jekyll_opts = server.config[:JekyllOptions]
          set_defaults
          super
        end

        # Add the ability to tap file.html the same way that Nginx does on our
        # Docker images (or on GitHub Pages.) The difference is that we might end
        # up with a different preference on which comes first.

        def search_file(req, res, basename)
          # /file.* > /file/index.html > /file.html
          super || super(req, res, "#{basename}.html")
        end

        def do_GET(req, res)
          rtn = super
          validate_and_ensure_charset(req, res)
          res.header.merge!(@headers)
          return rtn if SkipAnalyzer.skip_processing?(req, res, @jekyll_opts)

          processor = BodyProcessor.new(res.body, @jekyll_opts)
          processor.process!
          res.body = processor.new_body
          res.content_length = processor.content_length.to_s

          if processor.livereload_added
            res['X-Rack-LiveReload'] = '1'
          end

          rtn
        end

        private
        def validate_and_ensure_charset(_req, res)
          key = res.header.keys.grep(/content-type/i).first
          typ = res.header[key]

          unless typ =~ /;\s*charset=/
            res.header[key] = "#{typ}; charset=#{@jekyll_opts["encoding"]}"
          end
        end

        private
        def set_defaults
          hash_ = @jekyll_opts.fetch("webrick", {}).fetch("headers", {})
          DEFAULTS.each_with_object(@headers = hash_) do |(key, val), hash|
            hash[key] = val unless hash.key?(key)
          end
        end
      end
    end
  end
end
