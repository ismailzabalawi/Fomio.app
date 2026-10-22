# frozen_string_literal: true

RSpec.describe 'Fomio search operators and error envelopes', type: :request do
  before do
    SearchIndexer.enable
    Jobs.run_immediately!
    @member = Fabricate(:user)
    @root = Fabricate(:category)
    @child = Fabricate(:category, parent_category: @root)
    @outside = Fabricate(:category)
    @inside = Fabricate(:post, topic: Fabricate(:topic, category: @root), raw: 'operatorboundaryneedle inside phrase')
    @reply = Fabricate(:post, topic: @inside.topic, raw: 'operatorboundaryneedle inside reply')
    @child_post = Fabricate(:post, topic: Fabricate(:topic, category: @child), raw: 'operatorboundaryneedle inside phrase')
    @outside_post = Fabricate(:post, topic: Fabricate(:topic, category: @outside), raw: 'operatorboundaryneedle outside phrase')
    [@inside, @reply, @child_post, @outside_post].each { |post| SearchIndexer.index(post, force: true) }
  end

  def search(query, context: true, guard: true, extra: {}, headers: {})
    query += " category:#{@root.id}" if guard
    params = {q: query, page: 1}
    params.merge!(context: 'category', context_id: @root.id) if context
    get '/search.json', params: params.merge(extra), headers: headers
  end

  def ids
    Array(response.parsed_body['posts']).map { |post| post['id'] }
  end

  it 'reproduces unguarded uppercase topic override outside the selected category' do
    search("operatorboundaryneedle TOPIC:#{@outside_post.topic_id}", guard: false)
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@outside_post.id)
  end

  ["topic:%s", "TOPIC:%s"].each do |operator|
    it "intersects the generated numeric guard with #{operator}" do
      search("operatorboundaryneedle #{operator % @outside_post.topic_id}")
      expect(response.status).to eq(200)
      expect(ids).to be_empty
    end
  end

  ['category:%s', 'CATEGORIES:%s', '"category:%s"', "'category:%s'", 'category:=%s'].each do |operator|
    it "recognizes and intersects #{operator} even when quoting was intended literally" do
      search("operatorboundaryneedle #{operator % @outside.id}")
      expect(response.status).to eq(200)
      expect(ids).to be_empty
    end
  end

  it 'intersects a comma-union category filter with the final trusted category' do
    search("operatorboundaryneedle categories:#{@outside.id},#{@child.id}")
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@child_post.id)
  end

  it 'preserves a balanced ordinary phrase with the final guard' do
    search('"inside phrase"')
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@inside.id, @child_post.id)
  end

  it 'keeps unmatched quotes from escaping the numeric guard in this sample' do
    search("operatorboundaryneedle topic:#{@outside_post.topic_id} \"")
    expect(response.status).to eq(200)
    expect(ids).to be_empty
  end

  it 'lets all-posts change hit cardinality while remaining inside the guarded category' do
    search('operatorboundaryneedle in:all-posts')
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@inside.id, @reply.id, @child_post.id)
  end

  it 'treats an unknown category filter as empty rather than a grammar error' do
    search('operatorboundaryneedle category:nonexistentcategoryneedle')
    expect(response.status).to eq(200)
    expect(ids).to be_empty
    expect(response.parsed_body.dig('grouped_search_result', 'error')).to be_nil
  end

  it 'demonstrates skip_context removes the category restriction without a numeric guard' do
    search('operatorboundaryneedle', guard: false, extra: {skip_context: 'true'})
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@inside.id, @child_post.id, @outside_post.id)
  end

  it 'retains the numeric restriction even if skip_context is supplied' do
    search('operatorboundaryneedle', extra: {skip_context: 'true'})
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@inside.id, @child_post.id)
  end

  it 'shows a generated category token bypasses server minimum-length validation' do
    SiteSetting.min_search_term_length = 3
    search('x')
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@inside.id, @child_post.id)
  end

  it 'shows a generated category token turns empty user input into category-only results' do
    search('')
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@inside.id, @child_post.id)
  end

  it 'does not enforce PM exclusion through invented show parameters' do
    sign_in(@member)
    pm = Fabricate(:private_message_post, user: @member, raw: 'operatorboundaryneedle personal message')
    SearchIndexer.index(pm, force: true)
    search('operatorboundaryneedle in:all', context: false, guard: false, extra: {type_filter: 'topic', exclude_private_messages: true})
    expect(response.status).to eq(200)
    expect(ids).to include(pm.id)
  end

  it 'returns 400 for too-short user input without generated operators' do
    SiteSetting.min_search_term_length = 3
    search('xy', context: false, guard: false)
    expect(response.status).to eq(400)
    expect(response.parsed_body['error_type']).to eq('invalid_parameters')
  end

  it 'rejects a query hash as malformed' do
    get '/search.json', params: {q: {unexpected: 'value'}}
    expect(response.status).to eq(400)
  end

  it 'rejects embedded null bytes' do
    search("operatorboundaryneedle\u0000")
    expect(response.status).to eq(400)
  end

  ['11', '01', ' 1 ', '1.0', 'abc'].each do |page|
    it "rejects malformed or over-limit page #{page.inspect}" do
      search('operatorboundaryneedle', extra: {page: page})
      expect(response.status).to eq(400)
    end
  end

  ['0', '-1'].each do |page|
    it "normalizes page #{page} to the first page instead of rejecting" do
      search('operatorboundaryneedle', extra: {page: page})
      expect(response.status).to eq(200)
      expect(ids).to contain_exactly(@inside.id, @child_post.id)
    end
  end

  it 'rejects an invalid nested context type' do
    search('operatorboundaryneedle', extra: {search_context: {type: 'invalid', id: @root.id}})
    expect(response.status).to eq(400)
  end

  it 'rejects a nested context with no ID' do
    search('operatorboundaryneedle', extra: {search_context: {type: 'category'}})
    expect(response.status).to eq(400)
  end

  it 'lets nested context replace top-level context without the numeric guard' do
    search('operatorboundaryneedle', guard: false, extra: {search_context: {type: 'category', id: @outside.id}})
    expect(response.status).to eq(200)
    expect(ids).to contain_exactly(@outside_post.id)
  end

  it 'serializes a valid empty result with an optional topic collection and no grouped error' do
    search('nonmatchingoperatorboundaryneedle')
    expect(response.status).to eq(200)
    expect(ids).to be_empty
    expect(response.parsed_body['topics']).to be_nil
    expect(response.parsed_body.dig('grouped_search_result', 'error')).to be_nil
  end

  it 'returns 200 with grouped error on overload, not empty-search success' do
    global_setting :disable_search_queue_threshold, 0.2
    freeze_time
    search('operatorboundaryneedle', headers: {'HTTP_X_REQUEST_START' => "t=#{(Time.now - 1).to_f}"})
    expect(response.status).to eq(200)
    expect(ids).to be_empty
    expect(response.parsed_body.dig('grouped_search_result', 'error')).to be_present
  end

  it 'returns a search-specific 429 envelope without requiring Retry-After' do
    RateLimiter.enable
    SiteSetting.rate_limit_search_anon_user_per_second = 1
    freeze_time
    search('operatorboundaryneedle')
    expect(response.status).to eq(200)
    search('operatorboundaryneedle')
    expect(response.status).to eq(429)
    expect(response.parsed_body['failed']).to eq('FAILED')
    expect(response.parsed_body['message']).to be_present
    expect(response.headers['Retry-After']).to be_nil
  end

  it 'returns 403 not_logged_in when guest search is disabled' do
    SiteSetting.allow_anonymous_search = false
    search('operatorboundaryneedle')
    expect(response.status).to eq(403)
    expect(response.parsed_body['error_type']).to eq('not_logged_in')
  end

  [:revoked, :expired].each do |state|
    it "returns 403 invalid_access for a #{state} per-user key" do
      key = Fabricate(:readonly_user_api_key, user: @member)
      key.update!(state == :revoked ? {revoked_at: Time.zone.now} : {expires_at: 1.minute.ago})
      search('operatorboundaryneedle', headers: {HTTP_USER_API_KEY: key.key, HTTP_USER_API_CLIENT_ID: key.client.client_id})
      expect(response.status).to eq(403)
      expect(response.parsed_body['error_type']).to eq('invalid_access')
    end
  end
end
