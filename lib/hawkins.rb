require 'date'
require 'guard'
require 'jekyll'
require 'rack'
require 'safe_yaml/load'
require 'stringex_lite'
require 'thor'

require 'hawkins/cli'
require 'hawkins/guard'
require 'hawkins/version'

module Hawkins
  DEFAULT_EXTENSIONS = %w(
    md
    mkd
    mkdn
    markdown
    textile
    html
    haml
    slim
    xml
    yml
  )

  # When using pagination, Jekyll wants an index.html
  DEFAULT_INCLUDES = %w(
    *.less
    *.js
    *.css
    *.png
    *.jpg
    *.gif
    *.jpeg
    *.eot
    *.svg
    *.ttf
    *.woff
    404.html
    index.*
  )

  ISOLATION_FILE = ".isolation_config.yml"
end
