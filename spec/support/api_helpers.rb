module ApiHelpers
  def api_create(bucket, key, file=random_fixture_file)
    warn_if_not_test_bucket(bucket)
    put "/#{bucket}/#{key}", file.data, { 'CONTENT_TYPE' => file.type }.merge(authn_headers)
    file
  end

  def api_update(bucket, key, file=random_fixture_file)
    warn_if_not_test_bucket(bucket)
    post "/#{bucket}/#{key}", file.data, { 'CONTENT_TYPE' => file.type }.merge(authn_headers)
    file
  end

  def api_get(bucket, key)
    warn_if_not_test_bucket(bucket)
    get "/#{bucket}/#{key}", {}, authn_headers
  end

  def api_delete(bucket, key)
    delete "/#{bucket}/#{key}", {}, authn_headers
  end

  def claim_for(token, bucket)
    bucket = Coffer.buckets.new(bucket)
    bucket.content_type = 'application/json'
    bucket.data = { 'authorized_tokens' => [token] }
    bucket.store
  end

  def as_token(token)
    old_token, @token = @token, token
    if block_given?
      yield
      @token = old_token
    end
  end

  def as_unauthenticated(&block)
    as_token(nil, &block)
  end

  def warn_if_not_test_bucket(bucket)
    if !DataStore.test_buckets.include? bucket
      $stderr.puts "\n***Warning '#{bucket}' is not a test bucket we actively clear, add it to test_buckets in DataStore.test_buckets***"
    end
  end

  def authn_headers
    @token ? { "API_TOKEN" => @token, "API_KEY" => key_for_token(@token) } : {}
  end

  # TODO: This method is problematic at best. For test code, we should
  # just blow up if the token doesn't exist and require the test code
  # to ensure the token already has a key.
  def key_for_token(token)
    obj = Coffer.tokens.get(token)
    obj.data['key']
  rescue Riak::HTTPFailedRequest
    obj = Coffer.tokens.new(token)
    obj.content_type = 'application/json'
    obj.data = { 'key' => random_token }
    obj.store(:dw => 'all')
    retry # dangerous, what if we get infinity HTTPFaileds?
  end

  def random_token
    token = ''
    10.times { token << ('a'..'z').to_a[rand(26)] }
    token
  end
end
