# frozen_string_literal: true
RSpec.describe 'Fomio search settings contract', type: :request do
  it 'returns the configured search minimum through client site settings' do
    SiteSetting.min_search_term_length = 5
    get '/site/settings.json'
    expect(response.status).to eq(200)
    expect(response.parsed_body['min_search_term_length']).to eq(5)
    expect(response.parsed_body).not_to have_key('allow_anonymous_search')
  end

  it 'requires sign-in for client settings when login is required' do
    SiteSetting.login_required = true
    get '/site/settings.json'
    expect(response.status).to eq(403)
  end

  it 'allows an ordinary member to read search settings on a login-required site' do
    SiteSetting.login_required = true
    sign_in(Fabricate(:user))
    get '/site/settings.json'
    expect(response.status).to eq(200)
    expect(response.parsed_body['min_search_term_length']).to be_a(Integer)
  end
end
