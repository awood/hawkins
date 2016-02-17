require 'hawkins/post'
require 'hawkins/websockets'
require 'hawkins/liveserve'
require 'hawkins/version'

module Hawkins
  LIVERELOAD_PORT = 35729
  LIVERELOAD_FILES = File.expand_path("../js/",File.dirname(__FILE__))
end
