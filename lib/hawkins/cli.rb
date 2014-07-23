#! /usr/bin/env ruby

require 'date'
require 'guard'
require 'safe_yaml/load'
require 'stringex_lite'
require 'thor'

module Hawkins

  class Cli < Thor
    include Thor::Actions

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

    ISOLATION_FILE = ".isolation_config.yml"

    desc "isolate FILE ...", "work on a file or files in isolation (globs are allowed)"
    long_desc <<-LONGDESC
      Jekyll's regeneration capability is limited to regenerating the
      entire site.  This option will ignore all files except the ones you
      specify in order to speed regeneration.

      Keep in mind that Jekyll's exclusion mechanism is not aware of
      subdirectories so this command operates on the basename of all files
      that match the file or glob you provide.
    LONGDESC
    def isolate(*files)
      SafeYAML::OPTIONS[:default_mode] = :safe

      old_config = SafeYAML.load_file("_config.yml")
      config = {}

      pages = []
      pages << %w(md html textile markdown mkd mkdn).map do |ext|
        Dir.glob("**/*.#{ext}")
      end
      pages.flatten!.reject! { |f| File.fnmatch?('_site/*', f) }

      pages.select! do |p|
        content = File.read(p)
        # Jekyll only renders pages with YAML frontmatter.  See Jekyll's
        # convertible.rb read_yaml method.
        content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
      end
      config['exclude'] = pages
      config['exclude'] += old_config['exclude'] || []

      # When using pagination, Jekyll wants an index.html
      config['include'] = Set.new(%w(*.less *.js *.css *.png 404.html index.*))
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
        config['include'].add(*matches)
      end

      config['include'] = config['include'].to_a
      create_file(ISOLATION_FILE, YAML.dump(config))
      begin
        invoke(:serve, [])
      ensure
        remove_file(ISOLATION_FILE)
      end
    end

    desc "serve", "render and serve the site"
    def serve
      Guard.start
      while Guard.running do
        sleep 1
      end
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
