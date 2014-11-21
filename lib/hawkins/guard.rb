# encoding: UTF-8

require 'benchmark'
require 'guard/plugin'
require 'hawkins'
require 'jekyll'
require 'thin'

# Most of this is courtesy of the guard-jekyll-plus gem at
# https://github.com/imathis/guard-jekyll-plus

module Guard
  class Hawkins < Plugin
    def initialize(options={})
      super

      default_extensions = ::Hawkins::DEFAULT_EXTENSIONS

      @options = {
        :extensions     => [],
        :config         => Jekyll::Configuration.new.config_files({}),
        :drafts         => false,
        :future         => false,
        :config_hash    => nil,
        :silent         => false,
        :msg_prefix     => 'Jekyll'
      }.merge(options)

      @config = load_config(@options)
      @source = local_path(@config['source'])
      @destination = local_path(@config['destination'])
      @msg_prefix = @options[:msg_prefix]
      @app_prefix = 'Hawkins'

      # Convert array of extensions into a regex for matching file extensions
      # E.g. /\.md$|\.markdown$|\.html$/i
      extensions  = @options[:extensions].concat(default_extensions).flatten.uniq
      @extensions = Regexp.new(
        extensions.map { |e| (e << '$').gsub('\.', '\\.') }.join('|'),
        true
      )

      # set Jekyll server thread to nil
      @server_thread = nil

      # Create a Jekyll site
      @site = Jekyll::Site.new(@config)
    end

    def load_config(options)
      config = jekyll_config(options)

      # Override configuration with option values
      config['show_drafts'] ||= options[:drafts]
      config['future']      ||= options[:future]
      config
    end

    def reload_config!
      UI.info "Reloading Jekyll configuration!"
      @config = load_config(@options)
    end

    def start
      build
      start_server
      return if @config[:silent]
      msg = "#{@app_prefix} "
      msg += "watching and serving at #{@config['host']}:#{@config['port']}#{@config['baseurl']}"
      UI.info(msg)
    end

    def reload
      stop if !@server_thread.nil? && @server_thread.alive?
      reload_config!
      start
    end

    def reload_server
      stop_server
      start_server
    end

    def stop
      stop_server
    end

    def run_on_modifications(paths)
      # At this point we know @options[:config] is going to be an Array
      # thanks to the call the jekyll_config earlier.
      reload_config! if @options[:config].map { |f| paths.include?(f) }.any?
      matched = jekyll_matches paths
      unmatched = non_jekyll_matches paths

      if matched.size > 0
        build(matched, "Files changed: ", "  ~ ".yellow)
      elsif unmatched.size > 0
        copy(unmatched)
      end
    end

    def run_on_additions(paths)
      matched = jekyll_matches paths
      unmatched = non_jekyll_matches paths

      if matched.size > 0
        build(matched, "Files added: ", "  + ".green)
      elsif unmatched.size > 0
        copy(unmatched)
      end
    end

    def run_on_removals(paths)
      matched = jekyll_matches paths
      unmatched = non_jekyll_matches paths

      if matched.size > 0
        build(matched, "Files removed: ", "  x ".red)
      elsif unmatched.size > 0
        remove(unmatched)
      end
    end

    private

    def build(files=nil, message='', mark=nil)
      UI.info "#{@msg_prefix} #{message}" + "building...".yellow unless @config[:silent]
      if files
        puts '| '
        files.each { |file| puts '|' + mark + file }
        puts '| '
      end
      elapsed = Benchmark.realtime { Jekyll::Site.new(@config).process }
      unless @config[:silent]
        msg = "#{@msg_prefix} " + "build completed in #{elapsed.round(2)}s ".green
        msg += "#{@source} → #{@destination}"
        UI.info(msg)
      end
      rescue
        UI.error("#{@msg_prefix} build has failed") unless @config[:silent]
        stop_server
        throw :task_has_failed
    end

    # Copy static files to destination directory
    #
    def copy(files=[])
      files = ignore_stitch_sources files
      return false unless files.size > 0
      begin
        message = 'copied file'
        message += 's' if files.size > 1
        UI.info "#{@msg_prefix} #{message.green}" unless @config[:silent]
        puts '| '
        files.each do |file|
          path = destination_path file
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.cp(file, path)
          puts '|' + "  → ".green + path
        end
        puts '| '

      rescue
        UI.error "#{@msg_prefix} copy has failed" unless @config[:silent]
        UI.error e
        stop_server
        throw :task_has_failed
      end
      true
    end

    # Remove deleted source file/directories from destination
    def remove(files=[])
      # Ensure at least one file still exists (other scripts may clean up too)
      return false unless files.select { |f| File.exist? f }.size > 0
      begin
        message = 'removed file'
        message += 's' if files.size > 1
        UI.info "#{@msg_prefix} #{message.red}" unless @config[:silent]
        puts '| '

        files.each do |file|
          path = destination_path file
          if File.exist?(path)
            FileUtils.rm(path)
            puts '|' + "  x ".red + path
          end

          dir = File.dirname(path)
          next unless Dir[File.join(dir, '*')].empty?
          FileUtils.rm_r(dir)
          puts '|' + "  x ".red + dir
        end
        puts '| '

      rescue
        UI.error "#{@msg_prefix} remove has failed" unless @config[:silent]
        UI.error e
        stop_server
        throw :task_has_failed
      end
      true
    end

    def jekyll_matches(paths)
      paths.select { |file| file =~ @extensions }
    end

    def non_jekyll_matches(paths)
      paths.select { |file| !file.match(/^_/) && !file.match(@extensions) }
    end

    def jekyll_config(options)
      if options[:config_hash]
        config = options[:config_hash]
      elsif options[:config]
        options[:config] = [options[:config]] unless options[:config].is_a? Array
        config = options
      end
      Jekyll.configuration(config)
    end

    # TODO Use Pathname.relative_path_from or similar here
    def local_path(path)
      Dir.chdir('.')
      current = Dir.pwd
      path = path.sub current, ''
      if path == ''
        './'
      else
        path.sub(/^\//, '')
      end
    end

    def destination_path(file)
      if @source =~ /^\./
        File.join(@destination, file)
      else
        file.sub(/^#{@source}/, "#{@destination}")
      end
    end

    def start_server
      if @server_thread.nil?
        @server_thread = Thread.new do
          Thin::Server.start(@config['host'], @config['port'], :signals => false) do
            require 'rack/livereload'
            require 'hawkins/isolation'
            use Rack::LiveReload,
                :min_delay => 500,
                :max_delay => 2000,
                :no_swf => true,
                :source => :vendored
            run ::Hawkins::IsolationInjector.new
          end
        end
        UI.info "#{@app_prefix} running Rack" unless @config[:silent]
      else
        UI.warning "#{@app_prefix} using an old server thread!"
      end
    end

    def stop_server
      @server_thread.kill unless @server_thread.nil?
      @server_thread = nil
    end
  end
end
