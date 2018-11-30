require 'fileutils'
require 'tmpdir'

RSpec.describe StructureSqlMergeDriver do
  it "has a version number" do
    expect(StructureSqlMergeDriver::VERSION).not_to be nil
  end

  def test_merge(name)
    files_dir = File.realdirpath("fixtures/#{name}", __dir__)
    Dir.mktmpdir { |dir|
      FileUtils.cp(
        [
          File.join(files_dir, 'ours'),
          File.join(files_dir, 'base'),
          File.join(files_dir, 'theirs')
        ],
        dir
      )

      expect(
        system(
          File.realpath('../exe/git-merge-structure-sql', __dir__),
          File.join(dir, 'ours'),
          File.join(dir, 'base'),
          File.join(dir, 'theirs')
        )
      ).to eq true

      expect(
        File.read(File.join(dir, 'ours'))
      ).to eq File.read(File.join(files_dir, 'merged'))
    }
  end

  it "merges SQLite3 dump files" do
    test_merge('sqlite3')
  end

  it "merges newer MySQL dump files" do
    test_merge('mysql')
  end

  it "merges PostgreSQL dump files" do
    test_merge('postgresql')
  end
end
