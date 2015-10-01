require "test_helper"

class VersionsTest < Minitest::Test
  def setup
    @attacher = attacher { plugin :versions, names: [:thumb] }
    @uploader = @attacher.store
  end

  test "allows uploading versions" do
    versions = @uploader.upload(thumb: fakeio)

    assert_kind_of Shrine::UploadedFile, versions.fetch(:thumb)
  end

  test "processing into versions" do
    @uploader.singleton_class.class_eval do
      def process(io, context)
        {thumb: FakeIO.new(io.read.reverse)}
      end
    end
    versions = @uploader.upload(fakeio("original"))

    assert_equal "lanigiro", versions.fetch(:thumb).read
  end

  test "processing versions" do
    @uploader.singleton_class.class_eval do
      def process(hash, context)
        {thumb: FakeIO.new(hash.fetch(:thumb).read.reverse)}
      end
    end
    versions = @uploader.upload(thumb: fakeio("thumb"))

    assert_equal "bmuht", versions.fetch(:thumb).read
  end

  test "allows uploaded_file to accept JSON strings" do
    versions = @uploader.upload(thumb: fakeio)
    retrieved = @uploader.class.uploaded_file(JSON.dump(versions))

    assert_equal versions, retrieved
  end

  test "passes the version name to location generator" do
    @uploader.class.class_eval do
      def generate_location(io, version:)
        version.to_s
      end
    end
    versions = @uploader.upload(thumb: fakeio)

    assert_equal "thumb", versions.fetch(:thumb).id
  end

  test "overrides #uploaded?" do
    versions = @uploader.upload(thumb: fakeio)

    assert @uploader.uploaded?(versions)
  end

  test "deletes versions" do
    versions = @uploader.upload(thumb: fakeio)
    @uploader.delete(versions)

    refute versions[:thumb].exists?
  end

  test "attachment url accepts a version name" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_equal uploaded_file.url, @attacher.url(:thumb)
  end

  test "attachment url returns nil when a attachment doesn't exist" do
    assert_equal nil, @attacher.url(:thumb)
  end

  test "attachment url fails explicity when version isn't registered" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_raises(Shrine::Error) { @attacher.url(:unknown) }
  end

  test "attachment url doesn't fail if version is registered but missing" do
    @attacher.set({})
    @attacher.singleton_class.class_eval do
      def default_url(options)
        "missing #{options[:version]}"
      end
    end

    assert_equal "missing thumb", @attacher.url(:thumb)
  end

  test "attachment url returns raw file URL if versions haven't been generated" do
    @attacher.set(fakeio)

    assert_equal @attacher.url, @attacher.url(:thumb)
  end

  test "attachment url doesn't allow no argument when attachment is versioned" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_raises(Shrine::Error) { @attacher.url }
  end

  test "passes in :version to the default url" do
    @uploader.class.class_eval do
      def default_url(context)
        context.fetch(:version).to_s
      end
    end

    assert_equal "thumb", @attacher.url(:thumb)
  end

  test "forwards url options" do
    @attacher.cache.storage.singleton_class.class_eval do
      def url(id, **options)
        options
      end
    end
    @attacher.shrine_class.class_eval do
      def default_url(context)
        context
      end
    end

    uploaded_file = @attacher.set(fakeio)
    @attacher.set("thumb" => uploaded_file.data)
    assert_equal Hash[foo: "foo"], @attacher.url(:thumb, foo: "foo")

    @attacher.set(fakeio)
    assert_equal Hash[foo: "foo"], @attacher.url(:thumb, foo: "foo")

    @attacher.set(nil)
    assert_equal Hash[foo: "foo", name: :avatar, record: @attacher.record],
                 @attacher.url(foo: "foo")
    assert_equal Hash[version: :thumb, foo: "foo", name: :avatar, record: @attacher.record],
                 @attacher.url(:thumb, foo: "foo")
  end

  test "doesn't allow validating versions" do
    @uploader.class.validate {}
    uploaded_file = @uploader.upload(fakeio)

    assert_raises(Shrine::Error) { @attacher.set("thumb" => uploaded_file.data) }
  end

  test "attacher returns a hash of versions" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    assert_kind_of Shrine::UploadedFile, @attacher.get.fetch(:thumb)
  end

  test "attacher destroys versions successfully" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    @attacher.destroy

    refute uploaded_file.exists?
  end

  test "attacher replaces versions sucessfully" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data)

    @attacher.set("thumb" => @uploader.upload(fakeio).data)
    @attacher.replace

    refute uploaded_file.exists?
  end

  test "attacher promotes versions successfully" do
    cached_file = @attacher.set("thumb" => @uploader.upload(fakeio).data)
    @attacher.promote(cached_file)

    assert @attacher.store.uploaded?(@attacher.get[:thumb])
  end

  test "attacher filters the hash to only registered version" do
    uploaded_file = @uploader.upload(fakeio)
    @attacher.set("thumb" => uploaded_file.data, "malicious" => uploaded_file.data)

    assert_equal [:thumb], @attacher.get.keys
  end

  test "invalid IOs are still caught" do
    @uploader.singleton_class.class_eval do
      def process(io, context)
        {thumb: "invalid IO"}
      end
    end

    assert_raises(Shrine::InvalidFile) { @uploader.upload(fakeio) }
  end
end
