require 'jekyll'
require 'guard'

module Hawkins
  class Cli < Thor
    include Thor::Actions

    attr_accessor :jekyll_config

    def initialize(*args)
      super
      Jekyll.logger.log_level = :warn
      @jekyll_config = Jekyll::Configuration[Jekyll::Configuration::DEFAULTS]
      @jekyll_config.read_config_files(@jekyll_config.config_files({}))
    end

    desc "post TITLE", "create a post"
    option :editor, :default => ENV['VISUAL'] || ENV['EDITOR'] || 'vi'
    option :date, :default => Time.now.to_s
    def post(title)
      begin
        date = Date.parse(options[:date])
      rescue
        say_status(:error, "Could not parse '#{options[:date]}'", :red)
        exit 1
      end
      slug = title.to_url
      dest = path_to(:_posts)

      shell.mute { empty_directory(dest) }

      filename = "#{date.strftime('%Y-%m-%d')}-#{slug}.md"
      content = <<-CONTENT.gsub(/^\s*/, '')
        ---
        title: #{title}
        ---
      CONTENT

      create_file(path_to(dest, filename), content)

      case options[:editor]
      when /g?vim/
        editor_args = "+"
      when /x?emacs/
        editor_args = "+#{content.lines.count}"
      else
        editor_args = nil
      end

      exec(*[options[:editor], editor_args, path_to(dest, filename)].compact)
    end

    desc "isolate FILE ...", "work on a file or files in isolation (globs are allowed)"
    long_desc <<-LONGDESC
      Jekyll's regeneration capability is limited to regenerating the
      entire site.  This option will ignore all files except the ones you
      specify in order to speed regeneration.

      Keep in mind that Jekyll's inclusion mechanism is not aware of
      subdirectories so this command operates on the basename of all files
      that match the file or glob you provide.
    LONGDESC
    option :future, :type => :boolean, :default => false, :desc => "publish future dated posts"
    option :drafts, :type => :boolean, :default => false, :desc => "publish draft posts"
    def isolate(*files)
      SafeYAML::OPTIONS[:default_mode] = :safe

      pages = []
      pages << Hawkins::DEFAULT_EXTENSIONS.map do |ext|
        Dir.glob("**/*.#{ext}")
      end
      pages.flatten!.reject! { |f| File.fnmatch?('_site/*', f) }

      pages.select! do |p|
        content = File.read(p)
        # Jekyll only renders pages with YAML frontmatter.  See Jekyll's
        # convertible.rb read_yaml method.
        content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
      end

      isolation_config = {}
      isolation_config['exclude'] = pages.concat(jekyll_config['exclude'])
      isolation_config['include'] = Hawkins::DEFAULT_INCLUDES

      files.each do |glob|
        matches = Dir.glob(glob)
        matches.map! do |f|
          ext = File.extname(f)
          # If we have to add to this list from Rack, then Rack will have no
          # idea what the original file extension was.  Use a wildcard to
          # avoid this issue.
          "#{File.basename(f, ext)}.*"
        end
        if matches.empty?
          raise Thor::Error.new("Could not find any matches for #{glob}.")
        end
        isolation_config['include'] += matches
      end

      isolation_config['include'].uniq!

      # We have to write the isolation config out to a file so that the Guard
      # can detect when the configuration changes.
      create_file(Hawkins::ISOLATION_FILE, YAML.dump(isolation_config))

      begin
        invoke(:serve, [], options)
      ensure
        remove_file(Hawkins::ISOLATION_FILE)
      end
    end

    desc "serve", "render and serve the site"
    option :future, :type => :boolean, :default => false, :desc => "publish future dated posts"
    option :drafts, :type => :boolean, :default => false, :desc => "publish draft posts"
    def serve
      config_files = jekyll_config.config_files({}) || []
      if File.exist?(Hawkins::ISOLATION_FILE)
        config_files << Hawkins::ISOLATION_FILE
      end

      # By default Jekyll uses the absolute path and Guard doesn't so we need to fix that.
      dest = Pathname.new(jekyll_config['destination']).relative_path_from(Pathname.new(Dir.pwd))

      contents = <<-GUARDFILE.gsub(/^\s*/, '')
        interactor :off
        notification :off
        guard 'hawkins',
          :config => #{config_files},
          :drafts => #{options[:drafts]},
          :future => #{options[:future]} do
          watch %r{.*}
          ignore %r{^#{dest}}
        end

        guard 'livereload',
          :grace_period => 5 do
          watch %r{.*}
        end
      GUARDFILE
      Guard.start(:guardfile_contents => contents)
    end

    # Methods in the no_tasks block are not exposed to users
    no_tasks do
      def self.source_root
        File.expand_path("..", File.dirname(__FILE__))
      end

      # Builds a path within the source_root
      def path_to(*args)
        args = args.map(&:to_s)
        File.join(*args)
      end
    end
  end
end
