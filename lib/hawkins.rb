require 'date'
require 'guard'
require 'jekyll'
require 'safe_yaml/load'
require 'stringex_lite'
require 'thor'

require 'hawkins/cli'
require 'hawkins/version'
require 'hawkins/guard'

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

  ISOLATION_FILE = ".isolation_config.yml"
end
