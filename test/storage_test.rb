require "test_helper"

class StrorageTest < Minitest::Test
  test "every subclass gets its own copy" do
    uploader = Class.new(Shrine)
    uploader.storages[:foo] = "foo"

    another_uploader = Class.new(uploader)
    assert_equal "foo", another_uploader.storages[:foo]

    another_uploader.storages[:foo] = "bar"
    assert_equal "bar", another_uploader.storages[:foo]
    assert_equal "foo", uploader.storages[:foo]
  end

  test "raising error when storage doesn't exist" do
    assert_raises(Shrine::Error) do
      Shrine.new(:foo)
    end

    assert_raises(Shrine::Error) do
      Shrine::UploadedFile.new("id" => "123", "storage" => "foo", "metadata" => {})
    end
  end
end
