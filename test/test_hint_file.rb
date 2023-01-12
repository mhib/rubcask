# frozen_string_literal: true

require "test_helper"

class TestHintFile < Minitest::Test
  def setup
    @file = Tempfile.new("file")
    @hint_file = Rubcask::HintFile.new(@file)
  end

  def test_assert_reads_written_data
    @hint_file.append(Rubcask::HintEntry.new(0, "lorem", 0, 30))
    @hint_file.append(Rubcask::HintEntry.new(0, "ipsum", 30, 5))

    assert_equal(
      [Rubcask::HintEntry.new(0, "lorem", 0, 30), Rubcask::HintEntry.new(0, "ipsum", 30, 5)],
      @hint_file.each.to_a
    )
  end

  def teardown
    @file.unlink
  end
end
