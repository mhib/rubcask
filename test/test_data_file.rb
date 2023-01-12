# frozen_string_literal: true

require "test_helper"

class TestDataFile < Minitest::Test
  def setup
    @file = Tempfile.new("file")
    @data_file = Rubcask::DataFile.new(@file, 0)
  end

  def test_assert_reads_written_data
    @data_file.append(Rubcask::DataEntry.new(0, "lorem", "ipsum"))
    second_append_result = @data_file.append(Rubcask::DataEntry.new(0, "dolor", "sit"))

    assert_equal(Rubcask::DataEntry.new(0, "lorem", "ipsum"), @data_file[0])
    assert_equal(Rubcask::DataEntry.new(0, "dolor", "sit"), @data_file[second_append_result.value_pos])
  end

  def test_utf8
    str = "ąśdź"
    @data_file.append(Rubcask::DataEntry.new(0, "lorem", str))

    assert_equal(str.bytes, @data_file[0].value.bytes)
    assert_equal(str, @data_file[0].value.force_encoding("UTF-8"))
  end

  def test_each_returns_all_rows
    @data_file.append(Rubcask::DataEntry.new(0, "lorem", "ipsum"))
    @data_file.append(Rubcask::DataEntry.new(0, "dolor", "sit"))

    assert_equal(%w[lorem dolor], @data_file.each.map(&:key))
  end

  def teardown
    @file.unlink
  end
end
