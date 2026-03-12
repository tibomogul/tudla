# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Helper: find_or_create a Subscribable for a given record
def ensure_subscribable(record)
  Subscribable.find_or_create_by!(subscribable: record)
end

# Helper: find_or_create a project with its subscribable
def ensure_project(name:, team:)
  project = Project.find_or_create_by!(name: name, team: team)
  ensure_subscribable(project)
  project
end

# Helper: find_or_create a scope with its subscribable
def ensure_scope(name:, project:)
  scope = Scope.find_or_create_by!(name: name, project: project)
  ensure_subscribable(scope)
  scope
end

# Helper: find_or_create a task with its subscribable
def ensure_task(name:, scope:, project:, responsible_user:)
  task = Task.find_or_create_by!(name: name, scope: scope, project: project) do |t|
    t.responsible_user = responsible_user
  end
  ensure_subscribable(task)
  task
end

# ── Users ─────────────────────────────────────────────────────────────
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
charlie = User.find_or_create_by!(email: "charlie@example.com") do |u|
  u.username = "charlie"
  u.preferred_name = "Charlie"
  u.password = "password"
end
diana = User.find_or_create_by!(email: "diana@example.com") do |u|
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

# ── Organizations & Teams ─────────────────────────────────────────────
acme = Organization.find_or_create_by!(name: "Acme Corp")
globex = Organization.find_or_create_by!(name: "Globex Inc")

acme_rd = Team.find_or_create_by!(name: "R&D", organization: acme)
globex_rd = Team.find_or_create_by!(name: "R&D", organization: globex)
acme_sm = Team.find_or_create_by!(name: "S&M", organization: acme)
globex_sm = Team.find_or_create_by!(name: "S&M", organization: globex)

# ── Acme Corp Roles ───────────────────────────────────────────────────
UserPartyRole.find_or_create_by!(user: alice, party: acme, role: "admin")
UserPartyRole.find_or_create_by!(user: bob, party: acme_sm, role: "admin")
UserPartyRole.find_or_create_by!(user: evan, party: acme_rd, role: "admin")
UserPartyRole.find_or_create_by!(user: frank, party: acme_rd, role: "member")
UserPartyRole.find_or_create_by!(user: grace, party: acme_rd, role: "member")
UserPartyRole.find_or_create_by!(user: henry, party: acme_rd, role: "member")
UserPartyRole.find_or_create_by!(user: ivy, party: acme_sm, role: "member")

# ── Acme Corp Projects ───────────────────────────────────────────────
project_api_integration = ensure_project(name: "API Integration", team: acme_rd)
ensure_project(name: "Frontend Rendering", team: acme_rd)
ensure_project(name: "Product Rollout", team: acme_sm)
ensure_project(name: "Support Database", team: acme_sm)
globex_auth_update = ensure_project(name: "Auth Update", team: globex_rd)

# ── Acme Corp Scopes ─────────────────────────────────────────────────
scope_receive_order = ensure_scope(name: "Receive Order", project: project_api_integration)
scope_accept_order = ensure_scope(name: "Accept Order", project: project_api_integration)
ensure_scope(name: "Assign Order", project: project_api_integration)
ensure_scope(name: "Schedule Order", project: project_api_integration)
ensure_scope(name: "Submit Order", project: project_api_integration)

# ── Acme Corp Tasks ──────────────────────────────────────────────────
ensure_task(name: "Implement receive endpoint", scope: scope_receive_order, project: project_api_integration, responsible_user: alice)
ensure_task(name: "Extract data from XML and create job", scope: scope_receive_order, project: project_api_integration, responsible_user: alice)
ensure_task(name: "Implement Accept UI", scope: scope_accept_order, project: project_api_integration, responsible_user: alice)
ensure_task(name: "Send Accept Packet to API", scope: scope_accept_order, project: project_api_integration, responsible_user: alice)

# ── Acme Corp Reports ────────────────────────────────────────────────
acme_rd_reportable = Reportable.find_or_create_by!(reportable: acme_rd)
rr = ReportRequirement.find_or_create_by!(reportable: acme_rd_reportable, user: alice) do |r|
  r.schedule = IceCube::Schedule.new(Time.zone.parse("2025-10-28 09:00:00 AEST")) { |s|
    s.add_recurrence_rule(IceCube::Rule.weekly.day(1, 2, 3, 4, 5))
  }.to_hash
  r.reminder = 60 * 60
  r.delivery = [ {
    by: "email",
    type: "daily"
  }, {
    by: "slack",
    channel: "#acme_rd"
  } ]
  r.template = <<~MARKDOWN
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
end

rr.update(
  delivery: {
    slack: {
      enabled: true,
      webhook_url: "#{ENV['SLACK_WEBHOOK']}",
      channel: "#{ENV['SLACK_CHANNEL']}"
    }
  }
)

Report.find_or_create_by!(reportable: acme_rd_reportable, user: evan) do |r|
  r.as_of_at = rr.ice_cube_schedule.previous_occurrence(Time.zone.now)
  r.submitted_at = Time.zone.now
  r.content = rr.template
end

Reportable.find_or_create_by!(reportable: project_api_integration)

# ── Globex Inc ────────────────────────────────────────────────────────
UserPartyRole.find_or_create_by!(user: bob, party: globex, role: "admin")
UserPartyRole.find_or_create_by!(user: charlie, party: globex_rd, role: "admin")
UserPartyRole.find_or_create_by!(user: diana, party: globex_rd, role: "member")
UserPartyRole.find_or_create_by!(user: frank, party: globex_sm, role: "admin")
UserPartyRole.find_or_create_by!(user: grace, party: globex_sm, role: "member")
UserPartyRole.find_or_create_by!(user: henry, party: globex_rd, role: "member")

# Globex R&D projects
globex_data_pipeline = ensure_project(name: "Data Pipeline", team: globex_rd)
globex_infra_upgrade = ensure_project(name: "Infrastructure Upgrade", team: globex_rd)

# Globex S&M projects
globex_customer_portal = ensure_project(name: "Customer Portal", team: globex_sm)
globex_marketing_site = ensure_project(name: "Marketing Site Refresh", team: globex_sm)

# Auth Update scopes & tasks
scope_oauth_provider = ensure_scope(name: "OAuth Provider Setup", project: globex_auth_update)
scope_session_mgmt = ensure_scope(name: "Session Management", project: globex_auth_update)
scope_mfa = ensure_scope(name: "Multi-Factor Authentication", project: globex_auth_update)

ensure_task(name: "Configure OAuth2 client credentials", scope: scope_oauth_provider, project: globex_auth_update, responsible_user: charlie)
ensure_task(name: "Implement token refresh flow", scope: scope_oauth_provider, project: globex_auth_update, responsible_user: charlie)
ensure_task(name: "Add Redis-backed session store", scope: scope_session_mgmt, project: globex_auth_update, responsible_user: diana)
ensure_task(name: "Implement session expiry policy", scope: scope_session_mgmt, project: globex_auth_update, responsible_user: diana)
ensure_task(name: "Integrate TOTP authenticator", scope: scope_mfa, project: globex_auth_update, responsible_user: henry)
ensure_task(name: "Add SMS fallback for MFA", scope: scope_mfa, project: globex_auth_update, responsible_user: henry)

# Data Pipeline scopes & tasks
scope_ingestion = ensure_scope(name: "Data Ingestion", project: globex_data_pipeline)
scope_transformation = ensure_scope(name: "Data Transformation", project: globex_data_pipeline)

ensure_task(name: "Build Kafka consumer for event stream", scope: scope_ingestion, project: globex_data_pipeline, responsible_user: charlie)
ensure_task(name: "Implement dead-letter queue handling", scope: scope_ingestion, project: globex_data_pipeline, responsible_user: henry)
ensure_task(name: "Create ETL transform for user events", scope: scope_transformation, project: globex_data_pipeline, responsible_user: diana)
ensure_task(name: "Add data validation layer", scope: scope_transformation, project: globex_data_pipeline, responsible_user: diana)

# Infrastructure Upgrade scopes & tasks
scope_k8s_migration = ensure_scope(name: "Kubernetes Migration", project: globex_infra_upgrade)
scope_monitoring = ensure_scope(name: "Monitoring & Alerting", project: globex_infra_upgrade)

ensure_task(name: "Write Helm charts for core services", scope: scope_k8s_migration, project: globex_infra_upgrade, responsible_user: charlie)
ensure_task(name: "Configure horizontal pod autoscaling", scope: scope_k8s_migration, project: globex_infra_upgrade, responsible_user: henry)
ensure_task(name: "Set up Grafana dashboards", scope: scope_monitoring, project: globex_infra_upgrade, responsible_user: diana)
ensure_task(name: "Configure PagerDuty integration", scope: scope_monitoring, project: globex_infra_upgrade, responsible_user: charlie)

# Customer Portal scopes & tasks
scope_account_mgmt = ensure_scope(name: "Account Management", project: globex_customer_portal)
scope_billing = ensure_scope(name: "Billing & Invoices", project: globex_customer_portal)

ensure_task(name: "Build account settings page", scope: scope_account_mgmt, project: globex_customer_portal, responsible_user: frank)
ensure_task(name: "Implement user avatar upload", scope: scope_account_mgmt, project: globex_customer_portal, responsible_user: grace)
ensure_task(name: "Create invoice listing view", scope: scope_billing, project: globex_customer_portal, responsible_user: frank)
ensure_task(name: "Add Stripe payment method management", scope: scope_billing, project: globex_customer_portal, responsible_user: grace)

# Marketing Site Refresh scopes & tasks
scope_landing_pages = ensure_scope(name: "Landing Pages", project: globex_marketing_site)
scope_cms = ensure_scope(name: "CMS Integration", project: globex_marketing_site)

ensure_task(name: "Design hero section with new branding", scope: scope_landing_pages, project: globex_marketing_site, responsible_user: grace)
ensure_task(name: "Build pricing comparison table", scope: scope_landing_pages, project: globex_marketing_site, responsible_user: frank)
ensure_task(name: "Integrate headless CMS for blog", scope: scope_cms, project: globex_marketing_site, responsible_user: grace)
ensure_task(name: "Set up content preview workflow", scope: scope_cms, project: globex_marketing_site, responsible_user: frank)
