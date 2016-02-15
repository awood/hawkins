module Hawkins
  module Commands
    class Post < Jekyll::Command
      class << self
        def init_with_program(prog)
          prog.command(:post) do |c|
            c.syntax("new [options]")
            c.description("create a new post")
            c.action do |args, options|
              puts "Hello world"
            end
          end
        end
      end
    end
  end
end
