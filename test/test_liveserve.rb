require 'tmpdir'
require 'httpclient'
require 'thread'

require_relative './spec_helper'

module Hawkins
  RSpec.describe "Hawkins" do
    context "when running in liveserve mode" do
      let!(:destination) do
        Dir.mktmpdir("jekyll-destination")
      end

      let(:client) do
        HTTPClient.new
      end

      let(:standard_opts) do
        {
          "port" => 4000,
          "host" => "localhost",
          "baseurl" => "",
          "detach" => false,
          "destination" => destination,
          "reload_port" => Commands::LiveServe.singleton_class::LIVERELOAD_PORT,
        }
      end

      before(:each) do
        site = instance_double(Jekyll::Site)
        allow(Jekyll::Site).to receive(:new).and_return(site)
        allow(site).to receive(:in_source_dir)
          .with("_posts")
          .and_return("/no/thing/_posts")

        @thread = nil
        @started = Queue.new
      end

      after(:each) do
        Dir.delete(destination)
        @thread.exit unless @thread.nil?
      end

      def start_serving(opts)
        @thread = Thread.new do
          Commands::LiveServe.start(opts)
        end

        while !Commands::LiveServe.running?
          sleep(0.1)
        end
      end

      it "serves livereload.js over HTTP on the default LiveReload port" do
        opts = standard_opts
        allow(Jekyll).to receive(:configuration).and_return(opts)
        allow(Jekyll::Commands::Build).to receive(:process)

        capture_io do
          start_serving(opts)
        end

        res_content = client.get_content(
          "http://#{opts['host']}:#{opts['reload_port']}/livereload.js")
        expect(res_content).to include('LiveReload.on(')
      end

      it "serves nothing else over HTTP on the default LiveReload port" do
        opts = standard_opts
        allow(Jekyll).to receive(:configuration).and_return(opts)
        allow(Jekyll::Commands::Build).to receive(:process)

        capture_io do
          start_serving(opts)
        end

        res = client.get("http://#{opts['host']}:#{opts['reload_port']}/")
        expect(res.status_code).to eq(400)
        expect(res.content).to include('only serves livereload.js')
      end
    end
  end
end
