require 'json'
RateLimiter.disable

original_ts_config = Search.method(:ts_config)
missing_config = 'fomio_missing_search_configuration'
Search.define_singleton_method(:ts_config) { |*_arguments| missing_config }
observations = []
begin
  ['/search.json', '/search/query.json'].each do |path|
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host!('test.localhost')
    params = path == '/search.json' ? {q: 'databasefaultneedle', page: 1} : {term: 'databasefaultneedle'}
    session.get(path, params: params, headers: {'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'HTTP_USER_AGENT' => 'Fomio-contract-verification'})
    payload = JSON.parse(session.response.body)
    observation = {path: path, status: session.response.status, error: payload.dig('grouped_search_result', 'error'), posts_empty: payload['posts'] == [], topics_absent: !payload.key?('topics'), leaks_database_config: session.response.body.include?(missing_config)}
    raise "Failure was not explicit: #{path}" unless observation[:status] == 200 && observation[:error] == I18n.t('search.query_error') && observation[:posts_empty] && !observation[:leaks_database_config]
    observations << observation
  end
ensure
  Search.define_singleton_method(:ts_config, original_ts_config)
end
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host!('test.localhost')
session.get('/search.json', params: {q: 'nonmatchingdatabasefaultneedle', page: 1})
payload = JSON.parse(session.response.body)
raise 'Normal empty response failed after restoration' unless session.response.status == 200 && payload['posts'] == [] && payload.dig('grouped_search_result', 'error').nil?
observations << {case: 'normal_empty_after_restoring_configuration', status: session.response.status, error: nil, posts_empty: true}
File.write('/private/tmp/fomio-member-permissions/database-search-real-fault-results.json', JSON.pretty_generate(observations) + "\n")
puts JSON.generate(observations)
