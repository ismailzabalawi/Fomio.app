# frozen_string_literal: true

# Fomio Reporting & Safety backend contract checks (2026-10-17).
#
# Runs inside a Discourse checkout at the deployed revision
# 28529a6d63f99d8dea00017e69981ab42d4700fc against an isolated test database.
# Every account is a disposable fabricated record; every request uses a per-user
# API key with the native app's requested scopes. No passwords, admin API keys,
# or live-site resources are used. The transactional test database is rolled
# back after each example, which is the cleanup for every write below.
#
# Copy to spec/requests/ in that checkout and run with RAILS_DB=<isolated db>.

RSpec.describe "Fomio safety contracts" do
  NATIVE_SCOPES = %w[read write notifications session_info].freeze

  fab!(:admin)
  fab!(:moderator)
  fab!(:tl0) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:tl1) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:tl2) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:reporter2) { Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true) }
  fab!(:author) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: author) }
  fab!(:op) { Fabricate(:post, topic: topic, user: author, raw: "Controlled opening post for checks.") }
  fab!(:reply) { Fabricate(:post, topic: topic, user: author, raw: "Controlled reply for report checks.") }
  fab!(:staff_post) { Fabricate(:post, topic: topic, user: moderator) }

  def key_for(user)
    Fabricate(
      :user_api_key,
      user: user,
      scopes: NATIVE_SCOPES.map { |n| Fabricate.build(:user_api_key_scope, name: n) },
    ).key
  end

  def api(verb, path, user, params = {})
    send(verb, path, params: params, headers: { "User-Api-Key" => key_for(user) })
    response
  end

  def flag_summary(json)
    flag_ids = PostActionType.notify_flag_types.values
    (json["actions_summary"] || []).select { |a| flag_ids.include?(a["id"]) }
  end

  before do
    # Mirror the deployed Ignore groups read on 2026-10-16: admins, moderators, trust_level_2.
    SiteSetting.ignore_allowed_groups = "1|2|12"
  end

  describe "reporting" do
    it "lets an eligible member flag a reply and returns post JSON, not a receipt id" do
      res = api(:post, "/post_actions.json", tl1, id: reply.id, post_action_type_id: PostActionType.types[:off_topic])
      expect(res.status).to eq(200)
      expect(res.parsed_body["id"]).to eq(reply.id)
      off_topic = res.parsed_body["actions_summary"].find { |a| a["id"] == PostActionType.types[:off_topic] }
      expect(off_topic["acted"]).to eq(true)
      expect(flag_summary(res.parsed_body).none? { |a| a["can_act"] }).to eq(true)
      expect(ReviewableFlaggedPost.pending.find_by(target: reply)).to be_present
    end

    it "denies TL0 under the default flag groups but exposes no can_act for flags" do
      expect(SiteSetting.flag_post_allowed_groups).to eq("1|2|11")
      get "/posts/#{reply.id}.json", headers: { "User-Api-Key" => key_for(tl0) }
      expect(flag_summary(response.parsed_body).none? { |a| a["can_act"] }).to eq(true)
      res = api(:post, "/post_actions.json", tl0, id: reply.id, post_action_type_id: PostActionType.types[:spam])
      expect(res.status).to eq(403)
    end

    it "allows TL0 to report Illegal only when allow_all_users_to_flag_illegal_content is on" do
      SiteSetting.contact_email = "safety-check@example.com" # required by the setting validator; test DB only
      SiteSetting.allow_all_users_to_flag_illegal_content = true
      res = api(:post, "/post_actions.json", tl0, id: reply.id, post_action_type_id: PostActionType.types[:illegal], message: "Controlled illegal-content check.")
      expect(res.status).to eq(200)
    end

    it "makes a repeat flag a 403 and reports already-flagged through acted" do
      api(:post, "/post_actions.json", tl2, id: reply.id, post_action_type_id: PostActionType.types[:spam])
      res = api(:post, "/post_actions.json", tl2, id: reply.id, post_action_type_id: PostActionType.types[:inappropriate])
      expect(res.status).to eq(403)
      get "/posts/#{reply.id}.json", headers: { "User-Api-Key" => key_for(tl2) }
      expect(flag_summary(response.parsed_body).any? { |a| a["acted"] }).to eq(true)
    end

    it "accepts a require_message reason without a message (client must enforce)" do
      res = api(:post, "/post_actions.json", tl2, id: reply.id, post_action_type_id: PostActionType.types[:notify_moderators])
      expect(res.status).to eq(200)
      expect(PostAction.find_by(post: reply, user: tl2).related_post_id).to be_nil
    end

    it "creates a moderators PM when a message is supplied" do
      res = api(:post, "/post_actions.json", tl2, id: reply.id, post_action_type_id: PostActionType.types[:notify_moderators], message: "Controlled check: please review.")
      expect(res.status).to eq(200)
      related = PostAction.find_by(post: reply, user: tl2).related_post
      expect(related.topic.private_message?).to eq(true)
      expect(related.topic.allowed_groups.map(&:name)).to include("moderators")
    end

    it "flags a whole discussion by topic id with flag_topic" do
      res = api(:post, "/post_actions.json", tl2, id: topic.id, post_action_type_id: PostActionType.types[:inappropriate], flag_topic: "true")
      expect(res.status).to eq(200)
      expect(res.parsed_body["id"]).to eq(op.id)
      expect(PostAction.find_by(post: op, user: tl2).targets_topic).to eq(true)
    end

    it "emits details.can_flag_topic for an eligible member" do
      get "/t/#{topic.id}.json", headers: { "User-Api-Key" => key_for(tl2) }
      expect(response.parsed_body.dig("details", "can_flag_topic")).to eq(true)
      get "/t/#{topic.id}.json", headers: { "User-Api-Key" => key_for(tl0) }
      expect(response.parsed_body.dig("details", "can_flag_topic")).to be_nil
    end

    it "returns 404 for a removed post and 422 when already handled" do
      api(:post, "/post_actions.json", tl2, id: reply.id, post_action_type_id: PostActionType.types[:spam])
      reviewable = ReviewableFlaggedPost.find_by(target: reply)
      sign_in(moderator)
      put "/review/#{reviewable.id}/perform/agree_and_keep.json?version=#{reviewable.version}"
      expect(response.status).to eq(200)
      expect(reviewable.reload.status).to eq("approved")
      sign_out

      get "/posts/#{reply.id}.json", headers: { "User-Api-Key" => key_for(tl2) }
      spam = response.parsed_body["actions_summary"].find { |a| a["id"] == PostActionType.types[:spam] }
      expect(spam["acted"]).to eq(true) # reporter still sees acted after handling

      res = api(:post, "/post_actions.json", reporter2, id: reply.id, post_action_type_id: PostActionType.types[:spam])
      expect(res.status).to eq(422)

      removed = Fabricate(:post, topic: topic, user: author)
      PostDestroyer.new(admin, removed).destroy
      res = api(:post, "/post_actions.json", tl2, id: removed.id, post_action_type_id: PostActionType.types[:spam])
      expect(res.status).to eq(404)
    end

    it "makes a repeat on the same post 403 before the per-post limiter, and enforces the daily flag cap with 429" do
      targets = 3.times.map { Fabricate(:post, topic: topic, user: author) }
      RateLimiter.enable
      key = key_for(tl1)
      statuses = 3.times.map do
        post "/post_actions.json", params: { id: reply.id, post_action_type_id: PostActionType.types[:spam] }, headers: { "User-Api-Key" => key }
        response.status
      end
      expect(statuses).to eq([200, 403, 403])

      SiteSetting.max_flags_per_day = 2
      daily = targets.map do |target|
        post "/post_actions.json", params: { id: target.id, post_action_type_id: PostActionType.types[:off_topic] }, headers: { "User-Api-Key" => key }
        response.status
      end
      expect(daily.last).to eq(429)
      expect(response.headers["Retry-After"]).to be_present
      expect(response.parsed_body.dig("extras", "wait_seconds")).to be_present
    ensure
      RateLimiter.disable
    end
  end

  describe "ignore" do
    let(:forever) { 1000.years.from_now.beginning_of_month.iso8601 }

    it "denies TL0/TL1 and allows TL2 under the deployed groups" do
      [tl0, tl1].each do |u|
        res = api(:put, "/u/#{author.username}/notification_level.json", u, notification_level: "ignore", expiring_at: forever)
        # InvalidAccess is rescued into a localized 422 ("notification_level.ignore_error"), not a 403.
        expect(res.status).to eq(422)
        expect(res.parsed_body["errors"]).to be_present
        expect(IgnoredUser.exists?(user: u, ignored_user: author)).to eq(false)
      end
      res = api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever)
      expect(res.status).to eq(200)
    end

    it "allows TL0 once logged_in_users is added (proposed setting, test database only)" do
      SiteSetting.ignore_allowed_groups = "1|2|12|5"
      res = api(:put, "/u/#{author.username}/notification_level.json", tl0, notification_level: "ignore", expiring_at: forever)
      expect(res.status).to eq(200)
    end

    it "denies staff and self targets and rejects acting_user_id for members (all 422)" do
      expect(api(:put, "/u/#{moderator.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever).status).to eq(422)
      expect(api(:put, "/u/#{tl2.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever).status).to eq(422)
      expect(api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever, acting_user_id: reporter2.id).status).to eq(422)
      expect(IgnoredUser.where(user: [tl2, reporter2]).count).to eq(0)
      get "/u/#{moderator.username}/card.json", headers: { "User-Api-Key" => key_for(tl2) }
      expect(response.parsed_body.dig("user", "can_ignore_user")).to eq(false)
      expect(response.parsed_body.dig("user", "moderator")).to eq(true)
    end

    it "persists account-wide and is visible to a second client, card and current user" do
      api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever)
      get "/session/current.json", headers: { "User-Api-Key" => key_for(tl2) }
      expect(response.parsed_body.dig("current_user", "ignored_users")).to eq([author.username])
      expect(response.parsed_body.dig("current_user", "can_ignore_users")).to eq(true)
      expect(response.body).not_to include("expiring_at")
      get "/u/#{author.username}/card.json", headers: { "User-Api-Key" => key_for(tl2) }
      expect(response.parsed_body.dig("user", "ignored")).to eq(true)
      expect(IgnoredUser.find_by(user: tl2, ignored_user: author).expiring_at.year).to be > 3000
    end

    it "blanks ignored nested replies but a fresh post fetch keeps report permissions" do
      SiteSetting.nested_replies_enabled = true
      api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever)
      get "/n/#{topic.slug}/#{topic.id}.json", headers: { "User-Api-Key" => key_for(tl2) }
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("op_post", "cooked")).to be_present # OP body kept: client must hide
      node = response.parsed_body["roots"].find { |r| r["id"] == reply.id }
      expect(node["ignored_post_placeholder"]).to eq(true)
      expect(node["actions_summary"]).to eq([])
      get "/posts/#{reply.id}.json", headers: { "User-Api-Key" => key_for(tl2) }
      expect(flag_summary(response.parsed_body).any? { |a| a["can_act"] }).to eq(true)
    end

    it "rejects a new PM from the ignored sender and suppresses mention notifications" do
      api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever)
      res = api(:post, "/posts.json", author, title: "Controlled PM check title here", raw: "Controlled private message body.", archetype: "private_message", target_recipients: tl2.username)
      expect(res.status).to eq(422)
      Jobs.run_immediately!
      before = Notification.where(user: tl2).count
      api(:post, "/posts.json", author, topic_id: topic.id, raw: "Controlled mention of @#{tl2.username} here.")
      expect(Notification.where(user: tl2).count).to eq(before)
    end

    it "lets normal clear both ignore and mute; ignore replaces mute" do
      api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "mute")
      api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: forever)
      expect(MutedUser.exists?(user: tl2, muted_user: author)).to eq(false)
      res = api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "normal")
      expect(res.status).to eq(200)
      expect(IgnoredUser.exists?(user: tl2, ignored_user: author)).to eq(false)
      expect(MutedUser.exists?(user: tl2, muted_user: author)).to eq(false)
    end

    it "keeps finite expiry effective until the daily purge removes it" do
      api(:put, "/u/#{author.username}/notification_level.json", tl2, notification_level: "ignore", expiring_at: 1.day.from_now.iso8601)
      freeze_time 2.days.from_now
      expect(tl2.reload.ignored_user_ids).to include(author.id)
      Jobs::PurgeExpiredIgnoredUsers.new.execute({})
      expect(tl2.reload.ignored_user_ids).not_to include(author.id)
    end
  end
end
