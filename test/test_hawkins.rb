module Hawkins
  RSpec.describe "Hawkins" do
    context "when creating a post" do
      before(:each) do
        default_config = Jekyll::Configuration[Jekyll::Configuration::DEFAULTS]
        Jekyll::Configuration.stubs(:[]).returns(default_config)
        Jekyll::Configuration.any_instance.stubs(:config_files).returns([])
        Jekyll::Configuration.any_instance.stubs(:read_config_files).returns(default_config)
      end

      it 'fails on a bad post date' do
        _, err = capture_io do
          expect do
            Cli.start(%w(post --date BAD_DATE title))
          end.to raise_error(SystemExit)
        end

        expect(err).to match(/Could not parse/)
      end

      it 'fails on a missing title' do
        _, err = capture_io do
          expect do
            Cli.start(%w(post))
          end.to raise_error(SystemExit)
        end
        expect(err).to match(/called with no arguments/)
      end

      it 'creates a post for specific date' do
        title = "Party Like It's 1999"
        expected_body =<<-BODY.gsub(/^\s*/,'')
        ---
        title: #{title}
        ---
        BODY
        expected_file="_posts/1999-12-31-#{title.to_url}.md"
        Cli.no_commands do
          Cli.any_instance.expects(:empty_directory)
          Cli.any_instance.expects(:create_file).with(expected_file, expected_body)
          Cli.any_instance.expects(:exec).with('foo', expected_file)
        end

        Cli.start(%W(post --editor foo --date 1999-12-31 #{title}))
      end
    end
  end
end
