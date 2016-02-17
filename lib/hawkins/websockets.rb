require 'json'
require 'em-websocket'
require 'http/parser'

module Hawkins
  # The LiveReload protocol requires the server to serve livereload.js over HTTP
  # despite the fact that the protocol itself uses WebSockets.  This custom connection
  # class addresses the dual protocols that the server needs to understand.
  class HttpAwareConnection < EventMachine::WebSocket::Connection
    attr_reader :reload_file

    def initialize(opts)
      super
      @reload_file = File.join(LIVERELOAD_DIR, "livereload.js")
    end

    def dispatch(data)
      parser = Http::Parser.new
      parser << data

      # WebSockets requests will have a Connection: Upgrade header
      if parser.http_method != 'GET' || parser.upgrade?
        super
      else
        if parser.request_url =~ /^\/livereload.js/
          headers = [
            'HTTP/1.1 200 OK',
            'Content-Type: application/javascript',
            "Content-Length: #{File.size(reload_file)}",
            '',
            '',
          ].join("\r\n")
          send_data(headers)
          stream_file_data(reload_file).callback do
            close_connection_after_writing
          end
        else
          super
        end
      end
    end
  end

  class LiveReloadReactor
    attr_reader :thread
    attr_reader :opts

    def initialize(opts)
      @opts = opts
      @thread = nil
      @websockets = []
      @connections_count = 0
    end

    def stop
      @thread.kill
    end

    def running
      !@thread.nil? && @thread.alive?
    end

    def start
      @thread = Thread.new do
        # Use epoll if the kernel supports it
        EM.epoll
        # TODO enable SSL
        EM.run do
          Jekyll.logger.info("LiveReload Server:", "#{opts['host']}:#{opts['reload_port']}")
          EM.start_server(opts['host'], opts['reload_port'], HttpAwareConnection, opts) do |ws|
            ws.onopen do |handshake|
              connect(ws, handshake)
            end

            ws.onclose do
              disconnect(ws)
            end

            ws.onmessage do |msg|
              print_message(msg)
            end
          end
        end
      end

      Jekyll::Hooks.register(:site, :post_render) do |site|
        regenerator = Jekyll::Regenerator.new(site)
        @changed_pages = site.pages.select do |p|
          regenerator.regenerate?(p)
        end
      end

      Jekyll::Hooks.register(:site, :post_write) do |site|
        reload(@changed_pages) unless @changed_pages.nil?
        @changed_pages = nil
      end
    end

    private

    # For a description of the protocol see http://feedback.livereload.com/knowledgebase/articles/86174-livereload-protocol
    def reload(pages)
      pages.each do |p|
        msg = {
          :command => 'reload',
          :path => p.path,
          :liveCSS => true,
        }

        # TODO Add support for override URL?
        # See http://feedback.livereload.com/knowledgebase/articles/86220-preview-css-changes-against-a-live-site-then-uplo

        Jekyll.logger.debug("LiveReload:", "Reloading #{p.path}")
        @websockets.each do |ws|
          ws.send(JSON.dump(msg))
        end
      end
    end

    def connect(ws, handshake)
      @connections_count += 1
      Jekyll.logger.info("LiveReload:", "Browser connected") if @connections_count == 1
      ws.send(JSON.dump({
        :command => 'hello',
        :protocols => ['http://livereload.com/protocols/official-7'],
        :serverName => 'jekyll livereload'
      }))

      @websockets << ws
    end

    def disconnect(ws)
      @websockets.delete(ws)
    end

    def print_message(json_message)
      msg = JSON.parse(json_message)
      # Not sure what the 'url' command even does in LiveReload
      Jekyll.logger.info("LiveReload:", "Browser URL: #{msg['url']}") if msg['command'] == 'url'
    end
  end
end
