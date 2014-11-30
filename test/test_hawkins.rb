require 'helper'

class TestHawkins < MiniTest::Test
  context 'a post' do
    setup do
      default_config = Jekyll::Configuration[Jekyll::Configuration::DEFAULTS]
      Jekyll::Configuration.stubs(:[]).returns(default_config)
      Jekyll::Configuration.any_instance.stubs(:config_files).returns([])
      Jekyll::Configuration.any_instance.stubs(:read_config_files).returns(default_config)
    end

    should "create a post with the date" do
      skip("Not implemented")
    end

    should "fail on bad date" do
      _, err = capture_io do
        assert_raises(SystemExit) do
          Hawkins::Cli.start(%w(post --date BAD_DATE Title))
        end
      end
      assert_match(/Could not parse/, err)
    end

    should "fail on no title" do
      _, err = capture_io do
        assert_raises(SystemExit) do
          Hawkins::Cli.start(%w(post))
        end
      end
      assert_match(/called with no arguments/, err)
    end
  end
end
