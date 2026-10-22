# frozen_string_literal: true
RSpec.describe 'Fomio search fault observability', type: :request do
  it 'shows a rescued database-search exception is indistinguishable from empty results' do
    SearchIndexer.enable
    Jobs.run_immediately!
    post = Fabricate(:post, raw: 'faultobservabilityneedle discussion')
    SearchIndexer.index(post, force: true)
    get '/search.json', params: {q: 'faultobservabilityneedle', page: 1}
    expect(response.status).to eq(200)
    expect(response.parsed_body['posts'].map { |p| p['id'] }).to include(post.id)

    Search.any_instance.stubs(:topic_search).raises(ActiveRecord::StatementInvalid, 'synthetic local database-search failure')
    get '/search.json', params: {q: 'faultobservabilityneedle', page: 1}
    expect(response.status).to eq(200)
    expect(response.parsed_body['posts']).to eq([])
    expect(response.parsed_body.dig('grouped_search_result', 'error')).to be_nil
  end

  it 'keeps the JSON-suffixed search response valid for a crawler user-agent' do
    get '/search.json', params: {q: 'faultobservabilityneedle'}, headers: {HTTP_USER_AGENT: 'Googlebot'}
    expect(response.status).to eq(200)
    expect(response.media_type).to eq('application/json')
    expect(response.parsed_body).to be_a(Hash)
    expect(response.parsed_body['posts']).to be_an(Array)
  end
end
