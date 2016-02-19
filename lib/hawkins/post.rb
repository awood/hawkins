require 'stringex_lite'

module Hawkins
  module Commands
    class Post < Jekyll::Command
      class << self
        COMMAND_OPTIONS = {
          "date" => ["-d", "--date [DATE]", "Date to mark post"],
          "editor" => ["-e", "--editor [EDITOR]", "Editor to open"],
        }

        def init_with_program(prog)
          prog.command(:post) do |c|
            c.syntax("new [options]")
            c.description("create a new post")
            c.action do |args, options|
              options["date"] ||= Time.now.to_s
              begin
                date = Date.parse(options["date"])
              rescue
                Jekyll.logger.abort_with("Could not convert #{options['date']} into date format.")
              end

              if args.length != 1
                Jekyll.logger.abort_with(
                  "Please provide one argument to use as the post title.  Remember to quote multiword strings.")
              else
                title = args[0]
              end

              slug = title.to_url
              filename = "#{date.strftime('%Y-%m-%d')}-#{slug}.md"
              Jekyll.logger.info("Writing #{filename}")
            end
          end
        end
      end
    end
  end
end
