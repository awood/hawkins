require "webrick"
require "jekyll/commands/serve/servlet"

module Hawkins
  module Commands
    class LiveServe
      class SkipAnalyzer
        BAD_USER_AGENTS = [%r{MSIE}].freeze

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
          @options["ignore"] && @options["ignore"].any? { |filter| path[filter] }
        end

        def bad_browser?
          BAD_USER_AGENTS.any? { |pattern| @req['User-Agent'] =~ pattern }
        end

        def html?
          @res['Content-Type'] =~ %r{text/html}
        end
      end

      class BodyProcessor
        HEAD_TAG_REGEX = /<head>|<head[^(er)][^<]*>/

        attr_reader :content_length, :new_body, :livereload_added

        def initialize(body, options)
          @body = body
          @options = options
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
            # @body will be a File object
            @body.close
          end

          @content_length = 0
          @livereload_added = false

          @new_body.each do |line|
            if !@livereload_added && line['<head']
              line.gsub!(HEAD_TAG_REGEX) { |match| %(#{match}#{template.result(binding)}) }

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
              WEB_SOCKET_SWF_LOCATION = "<%= @options["baseurl"] %>/__livereload/WebSocketMain.swf";
              WEB_SOCKET_FORCE_FLASH = false;
            </script>
            <script type="text/javascript" src="<%= @options["baseurl"] %>/__livereload/swfobject.js"></script>
            <script type="text/javascript" src="<%= @options["baseurl"] %>/__livereload/web_socket.js"></script>
          <% end %>
          <script type="text/javascript">
            HAWKINS_LIVERELOAD_PORT = <%= @options["reload_port"] %>;
            HAWKINS_LIVERELOAD_PROTOCOL = <%= livereload_protocol %>;
          </script>
          <script type="text/javascript" src="<%= livereload_source %>"></script>
          TEMPLATE
          ERB.new(Jekyll::Utils.strip_heredoc(template))
        end

        def livereload_protocol
          use_ssl = @options["ssl_cert"] && @options["ssl_key"]
          use_ssl ? '"wss://"' : '"ws://"'
        end

        def livereload_source
          use_ssl = @options["ssl_cert"] && @options["ssl_key"]
          protocol = use_ssl ? "https" : "http"

          # Unclear what "snipver" does.  https://github.com/livereload/livereload-js states
          # that the recommended setting is 1.
          src = "#{protocol}://#{host_to_use}:#{@options['reload_port']}/livereload.js?snipver=1"

          # XHTML standard requires ampersands to be encoded as entities when in attributes
          # See http://stackoverflow.com/a/2190292
          src << "&amp;mindelay=#{@options['min_delay']}" if @options["min_delay"]
          src << "&amp;maxdelay=#{@options['max_delay']}" if @options["max_delay"]
          src << "&amp;port=#{@options['reload_port']}" if @options["reload_port"]
          src
        end
      end

      class ReloadServlet < Jekyll::Commands::Serve::Servlet
        def do_GET(req, res) # rubocop:disable MethodName
          rtn = super
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
      end
    end
  end
end
