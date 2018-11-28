require "test_helper"

class Git::Merge::Structure::SqlTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Git::Merge::Structure::Sql::VERSION
  end

  def test_it_does_something_useful
    assert false
  end
end
