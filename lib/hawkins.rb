# frozen_string_literal: true

require 'jekyll'

module Hawkins
  LIVERELOAD_PORT = 35729
  LIVERELOAD_DIR = File.expand_path("../js/", File.dirname(__FILE__))

  require 'hawkins/post'
  require 'hawkins/websockets'
  require 'hawkins/liveserve'
  require 'hawkins/version'
  require 'hawkins/thread_event.rb'
end
