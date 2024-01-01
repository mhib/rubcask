require "test_helper"

class TestMarshaledDirectory < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  CustomKey = Struct.new(:key)
  CustomValue = Struct.new(:value1, :value2)

  def test_write_read
    directory = Rubcask::MarshaledDirectory.new(Rubcask::Directory.new(@dir))

    key = CustomKey.new({ three: 3})
    value = CustomValue.new("1", [3,4])

    directory[key] = value
    assert_equal(value, directory[key])

    assert(directory.delete(key))

    assert_nil(directory[key])
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end
end
