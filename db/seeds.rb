# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# User model doesn't have soft delete, but use find_or_create_by for idempotency
alice = User.find_or_create_by!(email: "alice@example.com") do |u|
  u.username = "alice"
  u.preferred_name = "Alice"
  u.password = "password"
end
bob = User.find_or_create_by!(email: "bob@example.com") do |u|
  u.username = "bob"
  u.preferred_name = "Bob"
  u.password = "password"
end
User.find_or_create_by!(email: "charlie@example.com") do |u|
  u.username = "charlie"
  u.preferred_name = "Charlie"
  u.password = "password"
end
User.find_or_create_by!(email: "diana@example.com") do |u|
  u.username = "diana"
  u.preferred_name = "Diana"
  u.password = "password"
end
evan = User.find_or_create_by!(email: "evan@example.com") do |u|
  u.username = "evan"
  u.preferred_name = "Evan"
  u.password = "password"
end
frank = User.find_or_create_by!(email: "frank@example.com") do |u|
  u.username = "frank"
  u.preferred_name = "Frank"
  u.password = "password"
end
grace = User.find_or_create_by!(email: "grace@example.com") do |u|
  u.username = "grace"
  u.preferred_name = "Grace"
  u.password = "password"
end
henry = User.find_or_create_by!(email: "henry@example.com") do |u|
  u.username = "henry"
  u.preferred_name = "Henry"
  u.password = "password"
end
ivy = User.find_or_create_by!(email: "ivy@example.com") do |u|
  u.username = "ivy"
  u.preferred_name = "Ivy"
  u.password = "password"
end

users = User.all

users.each { |user| user.confirm }

# Soft-deletable models: use find_or_create_by for idempotency
acme = Organization.find_or_create_by!(name: "Acme Corp")
globex = Organization.find_or_create_by!(name: "Globex Inc")

acme_rd = Team.find_or_create_by!(name: "R&D", organization: acme)
globex_rd = Team.find_or_create_by!(name: "R&D", organization: globex)
acme_sm = Team.find_or_create_by!(name: "S&M", organization: acme)
Team.find_or_create_by!(name: "S&M", organization: globex)

UserPartyRole.create!(user: alice, party: acme, role: "admin")
UserPartyRole.create!(user: bob, party: acme_sm, role: "admin")
UserPartyRole.create!(user: evan, party: acme_rd, role: "admin")
UserPartyRole.create!(user: frank, party: acme_rd, role: "member")
UserPartyRole.create!(user: grace, party: acme_rd, role: "member")
UserPartyRole.create!(user: henry, party: acme_rd, role: "member")
UserPartyRole.create!(user: ivy, party: acme_sm, role: "member")

project_api_integration = Project.create!(name: "API Integration", team: acme_rd)
Subscribable.create!(subscribable: project_api_integration)
Subscribable.create!(subscribable: Project.create!(name: "Frontend Rendering", team: acme_rd))
Subscribable.create!(subscribable: Project.create!(name: "Product Rollout", team: acme_sm))
Subscribable.create!(subscribable: Project.create!(name: "Support Database", team: acme_sm))
Subscribable.create!(subscribable: Project.create!(name: "Auth Update", team: globex_rd))

scope_receive_order = Scope.create!(name: "Receive Order", project: project_api_integration)
scope_accept_order = Scope.create!(name: "Accept Order", project: project_api_integration)
Subscribable.create!(subscribable: scope_receive_order)
Subscribable.create!(subscribable: scope_accept_order)
Subscribable.create!(subscribable: Scope.create!(name: "Assign Order", project: project_api_integration))
Subscribable.create!(subscribable: Scope.create!(name: "Schedule Order", project: project_api_integration))
Subscribable.create!(subscribable: Scope.create!(name: "Submit Order", project: project_api_integration))

Subscribable.create!(subscribable: Task.create!(name: "Implement receive endpoint", scope: scope_receive_order, project: scope_receive_order.project, responsible_user: alice))
Subscribable.create!(subscribable: Task.create!(name: "Extract data from XML and create job", scope: scope_receive_order, project: scope_receive_order.project, responsible_user: alice))

Subscribable.create!(subscribable: Task.create!(name: "Implement Accept UI", scope: scope_accept_order, project: scope_accept_order.project, responsible_user: alice))
Subscribable.create!(subscribable: Task.create!(name: "Send Accept Packet to API", scope: scope_accept_order, project: scope_accept_order.project, responsible_user: alice))

acme_rd_reportable = Reportable.create!(reportable: acme_rd)
rr = ReportRequirement.create!(
  reportable: acme_rd_reportable,
  user: alice,
  # Schedule is daily at 9AM except for Saturday and Sunday
  schedule: IceCube::Schedule.new(Time.zone.parse("2025-10-28 09:00:00 AEST")) { |s|
    s.add_recurrence_rule(IceCube::Rule.weekly.day(1, 2, 3, 4, 5))
  }.to_hash,
  reminder: 60 * 60, # 1 hour
  delivery: [ {
    by: "email",
    type: "daily"
  }, {
    by: "slack",
    channel: "#acme_rd"
  } ],
  template: <<~MARKDOWN
*My Vibe:* :sunglasses: lots of meetings and 1-1s today

*_Yesterday's Wins (Completed Tasks):_*
* :white_check_mark: `Shared how to leverage AI to create ADRs, this will save time for devs`
* :white_check_mark: `Communicate Clearly Daily Update system`

*_Today's Focus & Status:_*
:large_green_circle: *_API Integration_* (2w)
* :hammer: `Groom cards and establish plan (Est: 2d)`
* :soon: `Generate test file for testing (Est: 1d)`

*_Blockers / @Mentions:_*
* :link: Partner to provide information on Access Token and API documentation @Charlie#{' '}
* :link: @Diana could you book time for sharing how the app persists data
MARKDOWN
)

rr.update(
  delivery: {
    slack: {
      enabled: true,
      webhook_url: "#{ENV['SLACK_WEBHOOK']}",
      channel: "#{ENV['SLACK_CHANNEL']}"
    }
  }
)

Report.create!(
  reportable: acme_rd_reportable,
  user: evan,
  as_of_at: rr.ice_cube_schedule.previous_occurrence(Time.zone.now),
  submitted_at: Time.zone.now,
  content: rr.template
)

project_api_integration_reportable = Reportable.create!(reportable: project_api_integration)
