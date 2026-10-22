# frozen_string_literal: true

RSpec.describe 'Fomio scoped member search permissions', type: :request do
  before do
    SearchIndexer.enable
    Jobs.run_immediately!
    @group = Fabricate(:group)
    @member = Fabricate(:user)
    @outsider = Fabricate(:user)
    @group.add(@member)
    @public_root = Fabricate(:category)
    @private_root = Fabricate(:private_category, group: @group, permission_type: CategoryGroup.permission_types[:readonly])
    @private_child = Fabricate(:private_category, group: @group, parent_category: @public_root)
    @public_post = Fabricate(:post, topic: Fabricate(:topic, category: @public_root), raw: 'permissionmatrixneedle public discussion')
    @private_post = Fabricate(:post, topic: Fabricate(:topic, category: @private_root), raw: 'permissionmatrixneedle restricted discussion')
    @child_post = Fabricate(:post, topic: Fabricate(:topic, category: @private_child), raw: 'permissionmatrixneedle restricted child discussion')
    [@public_post, @private_post, @child_post].each { |post| SearchIndexer.index(post, force: true) }
  end

  def search_as(user, category: nil, query: 'permissionmatrixneedle', guarded: true)
    sign_in(user) if user
    params = {q: query, page: 1}
    if category
      params.merge!(context: 'category', context_id: category.id)
      params[:q] += " category:#{category.id}" if guarded
    end
    get '/search.json', params: params
  end

  def post_ids
    Array(response.parsed_body['posts']).map { |post| post['id'] }
  end

  it 'rejects explicit private context for guests' do
    search_as(nil, category: @private_root)
    expect(response.status).to eq(403)
    expect(post_ids).to be_empty
  end

  it 'rejects explicit private context for an ordinary nonmember' do
    expect(@outsider.staff?).to eq(false)
    search_as(@outsider, category: @private_root)
    expect(response.status).to eq(403)
    expect(post_ids).to be_empty
  end

  it 'allows an ordinary readonly group member to search without granting posting' do
    expect(@member.staff?).to eq(false)
    search_as(@member, category: @private_root)
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@private_post.id)
    expect(Guardian.new(@member).can_post_in_category?(@private_root)).to eq(false)
  end

  it 'excludes a private child from public-root search for guests' do
    search_as(nil, category: @public_root)
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@public_post.id)
  end

  it 'excludes a private child from public-root search for ordinary nonmembers' do
    search_as(@outsider, category: @public_root)
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@public_post.id)
  end

  it 'includes a permitted private child in public-root search for its member' do
    search_as(@member, category: @public_root)
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@public_post.id, @child_post.id)
  end

  it 'returns empty numeric-filter results rather than granting private access' do
    search_as(@outsider, query: "permissionmatrixneedle category:#{@private_root.id}")
    expect(response.status).to eq(200)
    expect(post_ids).to be_empty
  end

  it 'excludes private roots and children from unscoped nonmember search' do
    search_as(@outsider)
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@public_post.id)
  end

  it 'includes only permitted category discussions in unscoped member search' do
    search_as(@member)
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@public_post.id, @private_post.id, @child_post.id)
  end

  it 'applies the same category security to a readonly per-user API key' do
    key = Fabricate(:readonly_user_api_key, user: @member)
    get '/search.json', params: {q: "permissionmatrixneedle category:#{@private_root.id}", page: 1, context: 'category', context_id: @private_root.id}, headers: {HTTP_USER_API_KEY: key.key, HTTP_USER_API_CLIENT_ID: key.client.client_id}
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@private_post.id)
  end

  it 'does not include private messages in default member discussion search' do
    pm = Fabricate(:private_message_post, user: @member, raw: 'permissionmatrixneedle personal message')
    SearchIndexer.index(pm, force: true)
    search_as(@member)
    expect(response.status).to eq(200)
    expect(post_ids).not_to include(pm.id)
  end

  it 'demonstrates that in:all changes HTTP search to include permitted private messages' do
    pm = Fabricate(:private_message_post, user: @member, raw: 'permissionmatrixneedle personal message')
    other_pm = Fabricate(:private_message_post, user: @outsider, raw: 'permissionmatrixneedle other personal message')
    [pm, other_pm].each { |post| SearchIndexer.index(post, force: true) }
    search_as(@member, query: 'permissionmatrixneedle in:all')
    expect(response.status).to eq(200)
    expect(post_ids).to include(pm.id)
    expect(post_ids).not_to include(other_pm.id)
  end

  it 'rejects another member private-message context' do
    search_as(@member, query: "permissionmatrixneedle personal_messages:#{@outsider.username}")
    expect(response.status).to eq(403)
  end

  it 'does not reveal an unauthorized topic through the topic operator' do
    search_as(@outsider, category: @public_root, query: "permissionmatrixneedle topic:#{@private_post.topic_id}")
    expect(response.status).to eq(200)
    expect(post_ids).to contain_exactly(@public_post.id)
  end
end
