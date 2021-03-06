require "test_helper"
require "shrine/plugins/download_endpoint"
require "rack/test_app"

describe Shrine::Plugins::DownloadEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(@uploader.class.download_endpoint))
  end

  before do
    @uploader = uploader { plugin :download_endpoint, storages: [:cache, :store] }
  end

  it "returns a file response" do
    io = fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024, content_type: "text/plain", filename: "content.txt")
    uploaded_file = @uploader.upload(io)
    response = app.get(uploaded_file.url)
    assert_equal 200, response.status
    assert_equal uploaded_file.read, response.body_binary
    assert_equal uploaded_file.size.to_s, response.headers["Content-Length"]
    assert_equal uploaded_file.mime_type, response.headers["Content-Type"]
    assert_equal "inline; filename=\"#{uploaded_file.original_filename}\"", response.headers["Content-Disposition"]
  end

  it "applies :disposition to response" do
    @uploader = uploader { plugin :download_endpoint, storages: [:cache, :store], disposition: "attachment" }
    uploaded_file = @uploader.upload(fakeio)
    response = app.get(uploaded_file.url)
    assert_equal "attachment; filename=\"#{uploaded_file.id}\"", response.headers["Content-Disposition"]
  end

  it "returns Cache-Control" do
    uploaded_file = @uploader.upload(fakeio)
    response = app.get(uploaded_file.url)
    assert_equal "max-age=31536000", response.headers["Cache-Control"]
  end

  it "returns Accept-Ranges" do
    uploaded_file = @uploader.upload(fakeio)
    response = app.get(uploaded_file.url)
    assert_equal "bytes", response.headers["Accept-Ranges"]
  end

  it "supports ranged requests" do
    uploaded_file = @uploader.upload(fakeio("content"))
    response = app.get(uploaded_file.url, headers: { "Range" => "bytes=2-4" })
    assert_equal 206,           response.status
    assert_equal "bytes 2-4/7", response.headers["Content-Range"]
    assert_equal "3",           response.headers["Content-Length"]
    assert_equal "nte",         response.body_binary
  end

  it "returns 404 for nonexisting file" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.data["id"] = "nonexistent"
    response = app.get(uploaded_file.url)
    assert_equal 404, response.status
    assert_equal "File Not Found", response.body_binary
    assert_equal "text/plain", response.content_type
  end

  it "returns 404 for nonexisting storage" do
    uploaded_file = @uploader.upload(fakeio)
    @uploader.class.storages.delete(uploaded_file.storage_key.to_sym)
    response = app.get(uploaded_file.url)
    assert_equal 404, response.status
    assert_equal "File Not Found", response.body_binary
    assert_equal "text/plain", response.content_type
  end

  it "adds :host to the URL" do
    @uploader.class.plugin :download_endpoint, host: "http://example.com"
    uploaded_file = @uploader.upload(fakeio)
    assert_match %r{http://example.com/\S+}, uploaded_file.url
  end

  it "adds :prefix to the URL" do
    @uploader.class.plugin :download_endpoint, prefix: "attachments"
    uploaded_file = @uploader.upload(fakeio)
    assert_match %r{/attachments/\S+}, uploaded_file.url
  end

  it "adds :host and :prefix to the URL" do
    @uploader.class.plugin :download_endpoint, host: "http://example.com", prefix: "attachments"
    uploaded_file = @uploader.upload(fakeio)
    assert_match %r{http://example.com/attachments/\S+}, uploaded_file.url
  end

  it "returns same URL regardless of metadata order" do
    uploaded_file = @uploader.upload(fakeio)
    uploaded_file.data["metadata"] = { "filename" => "a", "mime_type" => "b", "size" => "c" }
    url1 = uploaded_file.url
    uploaded_file.data["metadata"] = { "mime_type" => "b", "size" => "c", "filename" => "a" }
    url2 = uploaded_file.url
    assert_equal url1, url2
  end

  it "returns regular URL for non-selected storages" do
    @uploader.class.plugin :download_endpoint, storages: []
    uploaded_file = @uploader.upload(fakeio)
    assert_match /#{uploaded_file.id}$/, uploaded_file.url
  end

  it "supports legacy URLs" do
    uploaded_file = @uploader.upload(fakeio)
    response = app.get("/#{uploaded_file.storage_key}/#{uploaded_file.id}")
    assert_equal uploaded_file.read, response.body_binary
  end

  it "makes the endpoint inheritable" do
    endpoint1 = Class.new(@uploader.class).download_endpoint
    endpoint2 = Class.new(@uploader.class).download_endpoint
    refute_equal endpoint1, endpoint2
  end

  deprecated "adds DownloadEndpoint constant" do
    assert_equal @uploader.class.download_endpoint, @uploader.class::DownloadEndpoint
  end
end
