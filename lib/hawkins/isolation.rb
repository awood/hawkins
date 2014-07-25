#! /usr/bin/env ruby

require 'pathname'
require 'rack'
require 'safe_yaml/load'
require 'set'

module Hawkins
  class IsolationInjector
    attr_reader :site_root

    def initialize(options={})
      @options = options
      @site_root = @options[:site_root] || "_site"
      SafeYAML::OPTIONS[:default_mode] = :safe
    end

    def call(env)
      req = Rack::Request.new(env)

      path = Pathname.new(req.path_info).relative_path_from(Pathname.new('/'))
      if path.directory?
        path = path.join(Pathname.new("index.html")).cleanpath
      end
      path = path.to_s

      files = Dir[File.join(site_root, "**/*")].map do |f|
        Pathname.new(f).relative_path_from(Pathname.new(site_root)).to_s
      end

      if files.include?(path)
        mime = mime(path)
        file = file_info(File.join(site_root, path))
        body = file[:body]
        time = file[:time]
        hdrs = { 'Last-Modified'  => time }

        if time == req.env['HTTP_IF_MODIFIED_SINCE']
          [304, hdrs, []]
        else
          hdrs.update({ 'Content-length' => body.bytesize.to_s,
                        'Content-Type' => mime, } )
          [200, hdrs, [body]]
        end
      else
        handle_404(req, path)
      end
    end

    def handle_404(req, true_path)
      if File.exist?(Hawkins::ISOLATION_FILE)
        file = true_path
        # Use a wildcard since the origin file could be anything
        file = "#{File.basename(file, File.extname(file))}.*".force_encoding('utf-8')

        old_config = SafeYAML.load_file(ISOLATION_FILE)

        file_set = Set.new(old_config['include'])

        # Prevent loops.  If it's already in 'include'
        # then we've gone through here before.
        return static_error if file_set.include?(file)

        old_config['include'] = file_set.add(file).to_a

        File.open(ISOLATION_FILE, 'w') do |f|
          YAML.dump(old_config, f)
        end

        response = <<-PAGE.gsub(/^\s*/, '')
        <!DOCTYPE HTML>
        <html lang="en-US">
        <head>
          <meta charset="UTF-8">
          <title>Rendering #{req.path_info}</title>
        </head>
        <body>
          <h1>Hold on while I render that page for you!</h1>
        </body>
        PAGE

        headers ||= {}
        headers['Content-Length'] = response.bytesize.to_s
        headers['Content-Type'] = 'text/html'
        headers['Connection'] = 'keep-alive'
        [200, headers, [response]]
      else
        static_error
      end
    end

    def static_error
      error_page = File.join(site_root, "404.html")
      if File.exist?(error_page)
        body = file_info(error_page)[:body]
        mime = mime(error_page)
      else
        body = "Not found"
        mime = "text/plain"
      end
      return [404, {"Content-Type" => mime, "Content-length" => body.bytesize.to_s}, [body]]
    end

    def mime(path_info)
      Rack::Mime.mime_type(File.extname(path_info))
    end

    def file_info(path)
      expand_path = File.expand_path(path)
      File.open(expand_path, 'r') do |f|
        {
          :body => f.read,
          :time => f.mtime.httpdate,
          :expand_path => expand_path
        }
      end
    end
  end
end

