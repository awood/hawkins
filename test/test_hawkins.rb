module Hawkins
  RSpec.describe "Hawkins" do
    context "when creating a post" do
      before(:each) do
        default_config = Jekyll::Configuration[Jekyll::Configuration::DEFAULTS]
        allow_any_instance_of(Jekyll::Configuration).to receive(:[]).and_return(default_config)
        allow_any_instance_of(Jekyll::Configuration).to receive(:config_files).and_return([])
        allow_any_instance_of(Jekyll::Configuration).to receive(:read_config_files).and_return(default_config)
      end

      let(:date) do
        Time.now.strftime('%Y-%m-%d')
      end

      let(:cli_spy) do
        spy('Cli')
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

      # TODO There is a lot of redundancy here.  There's got to be a better way.
      # Look at http://betterspecs.org for ideas.
      it 'uses a provided date' do
        title = "Party Like It's 1999"
        expected_body =<<-BODY.gsub(/^\s*/,'')
        ---
        title: #{title}
        ---
        BODY
        expected_file="_posts/1999-12-31-#{title.to_url}.md"
        # Required to keep Thor from printing warning about undescribed commands.
        cli_spy.no_commands do
          expect(cli_spy).to receive(:empty_directory)
          expect(cli_spy).to receive(:create_file).with(expected_file, expected_body)
          expect(cli_spy).to receive(:exec)
        end

        cli_spy.start(%W(post --date 1999-12-31 #{title}))
      end

      it 'uses today as the default date' do
        title = "Raspberry Beret"
        expected_body =<<-BODY.gsub(/^\s*/,'')
        ---
        title: #{title}
        ---
        BODY
        expected_file="_posts/#{date}-#{title.to_url}.md"
        cli_spy.no_commands do
          expect(cli_spy).to receive(:empty_directory)
          expect(cli_spy).to receive(:create_file).with(expected_file, expected_body)
          expect(cli_spy).to receive(:exec)
        end

        cli_spy.start(%W(post #{title}))
      end

      it 'uses a provided editor' do
        title = "Little Red Corvette"
        expected_file="_posts/#{date}-#{title.to_url}.md"
        cli_spy.no_commands do
          expect(cli_spy).to receive(:empty_directory)
          expect(cli_spy).to receive(:create_file).with(expected_file, expected_body)
          expect(cli_spy).to receive(:exec).with('foo', expected_file)
        end

        cli_spy.start(%W(post --editor foo #{title}))
      end

      it 'uses the editor from the environment' do
        title = "Let's Go Crazy"
        expected_file="_posts/#{date}-#{title.to_url}.md"

        stub_const("ENV", ENV.to_h.tap { |h| h['VISUAL'] = 'default' })
        cli_spy.no_commands do
          expect(cli_spy).to receive(:empty_directory)
          expect(cli_spy).to receive(:create_file)
          expect(cli_spy).to receive(:exec).with('default', expected_file)
        end

        cli_spy.start(%W(post #{title}))
      end

      it 'sets correct vim options' do
        title = "When Doves Cry"
        expected_file="_posts/#{date}-#{title.to_url}.md"

        ['gvim', 'vim'].each do |editor|
          stub_const("ENV", ENV.to_h.tap { |h| h['VISUAL'] = editor })
          cli_spy.no_commands do
            expect(cli_spy).to receive(:empty_directory)
            expect(cli_spy).to receive(:create_file)
            expect(cli_spy).to receive(:exec).with(editor, '+', expected_file)
          end

          cli_spy.start(%W(post #{title}))
        end
      end

      it 'sets correct emacs options' do
        title = "Purple Rain"
        expected_file="_posts/#{date}-#{title.to_url}.md"

        ['xemacs', 'emacs'].each do |editor|
          stub_const("ENV", ENV.to_h.tap { |h| h['VISUAL'] = editor })
          cli_spy.no_commands do
            expect(cli_spy).to receive(:empty_directory)
            expect(cli_spy).to receive(:create_file)
            expect(cli_spy).to receive(:exec).with(editor, '+3', expected_file)
          end

          cli_spy.start(%W(post #{title}))
        end
      end
    end
  end
end
