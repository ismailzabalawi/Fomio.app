require 'json'
require 'rack/mock'
expected = 'Search could not be completed. Please try again.'
raise 'translation mismatch' unless I18n.t('search.query_error', locale: :en) == expected
original = Search.instance_method(:posts_query)
results = []
begin
  Search.send(:define_method, :posts_query) { |*args, **kwargs| raise ActiveRecord::StatementInvalid, 'FOMIO_SYNTHETIC_PRIVATE_DATABASE_DETAIL' }
  ['/search.json?q=Fomio', '/search/query.json?term=Fomio'].each do |path|
    env = Rack::MockRequest.env_for('https://meta.fomio.app' + path, 'HTTP_HOST' => 'meta.fomio.app', 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest', 'HTTP_ACCEPT' => 'application/json', 'REMOTE_ADDR' => '127.0.0.1')
    status, headers, body = Rails.application.call(env)
    raw = ''; body.each { |part| raw << part }; body.close if body.respond_to?(:close)
    data = JSON.parse(raw)
    error = data.dig('grouped_search_result', 'error')
    raise "unexpected status #{status}" unless status == 200
    raise "missing explicit error #{error.inspect}" unless error == expected
    raise 'partial posts' unless data['posts'] == []
    raise 'partial users' unless data['users'] == []
    raise 'partial categories' unless data['categories'] == []
    raise 'partial topics' unless data['topics'].nil? || data['topics'] == []
    raise 'continuation' unless data.dig('grouped_search_result','more_full_page_results').nil?
    raise 'database detail exposed' if raw.include?('FOMIO_SYNTHETIC_PRIVATE_DATABASE_DETAIL')
    results << {path: path.split('?').first, status: status, error: error, partial_results: false, database_detail_exposed: false}
    sleep 3
  end
ensure
  Search.send(:define_method, :posts_query, original)
end
puts 'FOMIO_DEPLOYED_PROBE=' + JSON.generate({mode: 'isolated production Rails process; synthetic exception; no database fault', results: results})
