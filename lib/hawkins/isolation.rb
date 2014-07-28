#! /usr/bin/env ruby

require 'pathname'
require 'rack'
require 'safe_yaml/load'
require 'set'

module Hawkins
  class IsolationInjector
    attr_reader :site_root
    attr_reader :isolation_file

    def initialize(options={})
      @options = options
      @site_root = @options[:site_root] || Jekyll.configuration({})['destination']
      @isolation_file = @options[:isolation_file] || Hawkins::ISOLATION_FILE
      SafeYAML::OPTIONS[:default_mode] = :safe
    end

    def call(env)
      req = Rack::Request.new(env)
      path = Pathname.new(req.path_info).relative_path_from(Pathname.new('/'))
      path = File.join(site_root, path.to_s)

      if File.directory?(path)
        path = File.join(path, "index.html")
      end
      path = Pathname.new(path).cleanpath.to_s

      files = Dir[File.join(site_root, "**/*")]
      if files.include?(path)
        mime = mime(path)
        file = file_info(path)
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
      if File.exist?(isolation_file)
        file = true_path
        # Use a wildcard since the origin file could be anything
        file = "#{File.basename(file, File.extname(file))}.*".force_encoding('utf-8')

        config = SafeYAML.load_file(isolation_file)

        file_set = Set.new(config['include'])

        # Prevent loops.  If it's already in 'include'
        # then we've gone through here before.
        return static_error if file_set.include?(file)

        config['include'] = file_set.add(file).to_a

        File.open(isolation_file, 'w') do |f|
          YAML.dump(config, f)
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

        headers = {}
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
      File.open(path, 'r') do |f|
        {
          :body => f.read,
          :time => f.mtime.httpdate,
          :expand_path => path
        }
      end
    end
  end
end

