require 'json'
require 'em-websocket'

class LiveReloadReactor
  attr_reader :thread
  attr_reader :opts
  attr_reader :connections_count
  attr_reader :websockets

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
      EM.run do
        Jekyll.logger.info("LiveReload Server:", "#{opts['host']}:#{opts['reload_port']}")
        EM::WebSocket.run(:host => opts['host'], :port => opts['reload_port']) do |ws|
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

    Jekyll::Hooks.register(:site, :post_write) do |site|
    end
  end

  private

  def connect(ws, handshake)
    @connections_count += 1
    Jekyll.logger.info("LiveReload:", "Browser connected") if connections_count == 1
    ws.send(JSON.dump({
      :command => 'hello',
      :protocols => ['http://livereload.com/protocols/official-7'],
      :serverName => 'jekyll'
    }))

    @websockets << ws
  end

  def disconnect(ws)
    @websockets.delete(ws)
  end

  def print_message(json_message)
    msg = JSON.parse(json_message)
    Jekyll.logger.info("LiveReload:", "Browser URL: #{msg['url']}") if msg['command'] == 'url'
  end
end
