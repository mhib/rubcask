# frozen_string_literal: true

require "test_helper"

class TestHintedDataFile < Minitest::Test
  def setup
    @file = Tempfile.new(["file", "1.data"])
    @file.close
    @hinted_file = Rubcask::HintedFile.new(@file.path)
  end

  def test_load_keyentries_without_hint_file
    first_insert = @hinted_file.append(Rubcask::DataEntry.new(1, "key1", "value1"))
    second_insert = @hinted_file.append(Rubcask::DataEntry.new(2, "key2", "value2"))
    third_insert = @hinted_file.append(Rubcask::DataEntry.new(3, "key3", "value3"))
    @hinted_file.flush

    new_hinted_file = Rubcask::HintedFile.new(@file.path)
    assert_equal(
      [["key1", first_insert], ["key2", second_insert], ["key3", third_insert]],
      new_hinted_file.each_keydir_entry.to_a
    )
  end

  def test_load_keyentries_with_hint_file
    first_insert = @hinted_file.append(Rubcask::DataEntry.new(1, "key1", "value1"))
    second_insert = @hinted_file.append(Rubcask::DataEntry.new(2, "key2", "value2"))
    third_insert = @hinted_file.append(Rubcask::DataEntry.new(3, "key3", "value3"))
    @hinted_file.flush
    @hinted_file.save_hint_file

    new_hinted_file = Rubcask::HintedFile.new(@file.path)
    assert(new_hinted_file.has_hint_file?)
    assert_equal(
      [["key1", first_insert], ["key2", second_insert], ["key3", third_insert]],
      new_hinted_file.each_keydir_entry.to_a
    )
  end

  def test_append_removes_hint_file
    @hinted_file.append(Rubcask::DataEntry.new(1, "key1", "value1"))
    @hinted_file.append(Rubcask::DataEntry.new(2, "key2", "value2"))
    @hinted_file.append(Rubcask::DataEntry.new(3, "key3", "value3"))

    @hinted_file.save_hint_file

    new_hinted_file = Rubcask::HintedFile.new(@file.path)
    new_hinted_file.append(Rubcask::DataEntry.new(4, "key", "value"))
    assert(new_hinted_file.dirty?)
    refute(new_hinted_file.has_hint_file?)
  end

  def teardown
    @file.unlink
  end
end
