# frozen_string_literal: true

require "test_helper"

class TestDirectoryDataFile < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def test_write_read
    directory = Rubcask::Directory.new(@dir)

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
      if idx.even?
        directory.delete(str_idx)
      end
    end

    assert_equal(500, directory.key_count)
    assert_equal(Set.new((1..1000).reject(&:even?).map(&:to_s)), Set.new(directory.keys))

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      if idx.even?
        assert_nil(directory[str_idx])
      else
        assert_equal("a" * idx, directory[str_idx])
      end
    end
  end

  def test_write_read_not_threadsafe
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |c| c.threadsafe = false })

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
      if idx.even?
        directory.delete(str_idx)
      end
    end

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      if idx.even?
        assert_nil(directory[str_idx])
      else
        assert_equal("a" * idx, directory[str_idx])
      end
    end
  end

  def test_read_after_close
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::KILOBYTE * 64 })

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
      if idx.even?
        directory.delete(str_idx)
      end
    end

    directory.close
    directory = Rubcask::Directory.new(@dir)

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      if idx.even?
        assert_nil(directory[str_idx])
      else
        assert_equal("a" * idx, directory[str_idx])
      end
    end
  end

  def test_utf8_key
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::KILOBYTE * 64 })
    directory["żółć"] = "lorem"
    assert_equal("lorem", directory["żółć"])
  end

  def test_merge_generate_files
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::KILOBYTE * 64 })

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
      if idx.even?
        directory.delete(str_idx)
      end
    end
    directory["1"] = "asdf"

    old_files = Dir.glob(File.join(@dir, "*.data"))
    directory.merge
    new_files = Dir.glob(File.join(@dir, "*.data"))
    assert_in_delta(old_files.size / 2, new_files.size, 1)

    hint_files = Dir.glob(File.join(@dir, "*.hint"))
    assert_equal(new_files.size - 1, hint_files.size)
    assert_equal("asdf", directory["1"])
  end

  def test_merge_remove_expired_entries
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::KILOBYTE * 64 })

    1.upto(1_000) do |idx|
      directory.set_with_ttl(idx.to_s, "a" * idx, 1)
    end

    Timecop.freeze(Time.now + 2)
    directory.merge

    new_files = Dir.glob(File.join(@dir, "*.data"))
    assert_equal(1, new_files.size)

    hint_files = Dir.glob(File.join(@dir, "*.hint"))
    assert_equal(0, hint_files.size)
  ensure
    Timecop.return
  end

  def test_load_after_merge
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::MEGABYTE * 1 })

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
      if idx.even?
        directory.delete(str_idx)
      elsif idx % 5 == 0
        directory[str_idx] = "b" * idx
      end
    end

    directory.merge
    directory.close

    directory = Rubcask::Directory.new(@dir)

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      if idx.even?
        assert_nil(directory[str_idx])
      elsif idx % 5 == 0
        assert_equal("b" * idx, directory[str_idx])
      else
        assert_equal("a" * idx, directory[str_idx])
      end
    end
  end

  def test_delete_that_creates_a_new_file
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::KILOBYTE })

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
    end

    old_files = Set.new(Dir.glob(File.join(@dir, "*.data")))

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory.delete(str_idx)
    end

    new_files = Set.new(Dir.glob(File.join(@dir, "*.data")))
    assert(new_files > old_files)
  end

  def test_delete_expired_record
    directory = Rubcask::Directory.new(@dir)

    now = Time.now
    directory.set_with_ttl("key1", "value1", 1)
    directory.set_with_ttl("key2", "value2", 100)
    directory["key3"] = "value3"

    Timecop.freeze(now + 2)

    files = Dir.glob(File.join(@dir, "*.data"))
    assert_equal(1, files.size)
    file = files[0]
    prev_size = File.size(file)
    directory.delete("key1")
    assert_equal(prev_size, File.size(file))
    directory.delete("key2")
    refute_equal(prev_size, File.size(file))

    prev_size = File.size(file)

    directory.delete("key3")
    refute_equal(prev_size, File.size(file))
  ensure
    Timecop.return
  end

  def test_set_with_ttl
    directory = Rubcask::Directory.new(@dir)

    now = Time.now

    directory.set_with_ttl("key", "value", 300)

    assert_equal("value", directory["key"])

    Timecop.freeze(now + 60)

    assert_equal("value", directory["key"])

    Timecop.freeze(now + 301)

    assert_nil(directory["key"])

    directory["key"] = "value2"
    assert_equal("value2", directory["key"])
  ensure
    Timecop.return
  end

  def test_set_with_ttl_load
    directory = Rubcask::Directory.new(@dir)

    now = Time.now
    directory["key"] = "not_good"

    directory.set_with_ttl("key", "value", 300)

    assert_equal("value", directory["key"])

    Timecop.freeze(now + 60)

    assert_equal("value", directory["key"])

    Timecop.freeze(now + 301)
    assert_nil(directory["key"])

    directory.close

    directory = Rubcask::Directory.new(@dir)

    assert_nil(directory["key"])
  ensure
    Timecop.return
  end

  def test_set_with_ttl_raises_when_negative_ttl
    directory = Rubcask::Directory.new(@dir)

    assert_raises(ArgumentError) { directory.set_with_ttl("key", "value", -1) }
  end

  def test_with_directory
    Rubcask::Directory.with_directory(@dir) do |directory|
      directory["lorem"] = "ipsum"
      assert_equal("ipsum", directory["lorem"])
    end
  end

  def test_each
    directory = Rubcask::Directory.new(@dir)

    directory["key1"] = "value1"
    directory["key2"] = "value2"
    directory["key3"] = "value3"
    directory.delete("key3")
    directory.close

    directory = Rubcask::Directory.new(@dir)

    assert_equal(Set[["key1", "value1"], ["key2", "value2"]], directory.each.to_set)
  ensure
    directory.close
  end

  def test_each_key
    directory = Rubcask::Directory.new(@dir)

    directory["key1"] = "value1"
    directory["key2"] = "value2"
    directory["key3"] = "value3"
    directory.delete("key3")
    directory.close

    directory = Rubcask::Directory.new(@dir)

    assert(Set["key1", "key2"] <= directory.each_key.to_set)
    assert(Set["key1", "key2", "key3"] >= directory.each_key.to_set)
  ensure
    directory.close
  end

  def test_regenerate_hint_files
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::KILOBYTE * 64 })

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
      if idx.even?
        directory.delete(str_idx)
      end
    end
    directory["1"] = "asdf"

    files = Dir.glob(File.join(@dir, "*.data"))
    directory.regenerate_hint_files!
    assert_equal(Dir.glob(File.join(@dir, "*.hint")).size, files.size)
    timestamps = Dir.glob(File.join(@dir, "*.hint")).sort.map { |x| File.ctime(x) }
    directory.regenerate_hint_files!
    refute_equal(timestamps, Dir.glob(File.join(@dir, "*.hint")).sort.map { |x| File.ctime(x) })
  end

  def test_generate_missing_hint_files
    directory = Rubcask::Directory.new(@dir, config: Rubcask::Config.new { |x| x.max_file_size = Rubcask::Bytes::KILOBYTE * 64 })

    1.upto(1_000) do |idx|
      str_idx = idx.to_s
      directory[str_idx] = "a" * idx
      if idx.even?
        directory.delete(str_idx)
      end
    end
    directory["1"] = "asdf"

    files = Dir.glob(File.join(@dir, "*.data"))
    directory.generate_missing_hint_files!
    assert_equal(Dir.glob(File.join(@dir, "*.hint")).size, files.size)
    timestamps = Dir.glob(File.join(@dir, "*.hint")).sort.map { |x| File.ctime(x) }
    directory.generate_missing_hint_files!
    assert_equal(timestamps, Dir.glob(File.join(@dir, "*.hint")).sort.map { |x| File.ctime(x) })
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end
end
