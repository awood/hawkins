require "webrick"

module Hawkins
  module Commands
    class LiveServe
      class BodyProcessor
        LIVERELOAD_JS_PATH = '/__rack/livereload.js'
        HEAD_TAG_REGEX = /<head>|<head[^(er)][^<]*>/
        LIVERELOAD_PORT = 35729

        attr_reader :content_length, :new_body, :livereload_added

        def protocol
          @options[:protocol] || "http"
        end

        def livereload_local_uri
          "#{protocol}://localhost:#{@options[:live_reload_port]}/livereload.js"
        end

        def initialize(body, options)
          @body, @options = body, options
          @options[:live_reload_port] ||= LIVERELOAD_PORT

          @processed = false
        end

        def force_swf?
          @options[:force_swf]
        end

        def with_swf?
          !@options[:no_swf]
        end

        def use_vendored?
          return @use_vendored if @use_vendored

          if @options[:source]
            @use_vendored = (@options[:source] == :vendored)
          else
            require 'net/http'
            require 'uri'

            uri = URI.parse(livereload_local_uri)

            http = Net::HTTP.new(uri.host, uri.port)
            http.read_timeout = 1

            begin
              http.send_request('GET', uri.path)
              @use_vendored = false
            rescue ::Timeout::Error, Errno::ECONNREFUSED, EOFError, IOError
              @use_vendored = true
            rescue => e
              $stderr.puts e.inspect
              raise e
            end
          end

          @use_vendored
        end

        def processed?
          @processed
        end

        def process!
          @new_body = []
          begin
            @body.each { |line| @new_body << line.to_s }
          ensure
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

        def app_root
          ENV['RAILS_RELATIVE_URL_ROOT'] || ''
        end

        def host_to_use
          (@options[:host] || 'localhost').gsub(%r{:.*}, '')
        end

        def template
          template = <<-TEMPLATE
          <% if with_swf? %>
            <script type="text/javascript">
              WEB_SOCKET_SWF_LOCATION = "/__rack/WebSocketMain.swf";
              <% if force_swf? %>
                WEB_SOCKET_FORCE_FLASH = true;
              <% end %>
            </script>
            <script type="text/javascript" src="<%= app_root %>/__rack/swfobject.js"></script>
            <script type="text/javascript" src="<%= app_root %>/__rack/web_socket.js"></script>
          <% end %>
          <script type="text/javascript">
            RACK_LIVERELOAD_PORT = <%= @options[:live_reload_port] %>;
          </script>
          <script type="text/javascript" src="<%= livereload_source %>"></script>
          TEMPLATE
          ERB.new(template)
        end

        def livereload_source
          if use_vendored?
            src = "#{app_root}#{LIVERELOAD_JS_PATH.dup}?host=#{host_to_use}"
          else
            src = livereload_local_uri.dup.gsub('localhost', host_to_use) + '?'
          end

          src << "&amp;mindelay=#{@options[:min_delay]}" if @options[:min_delay]
          src << "&amp;maxdelay=#{@options[:max_delay]}" if @options[:max_delay]
          src << "&amp;port=#{@options[:port]}" if @options[:port]

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
          processor = BodyProcessor.new(res.body, {})
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
