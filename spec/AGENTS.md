# Testing

## Framework
RSpec 8.0 + rspec-rails, FactoryBot, SimpleCov, Capybara

## Structure
```
spec/
├── models/          # 10 model specs (estimate_cacheable_spec is most comprehensive: 12 examples)
├── requests/        # 9 request specs (integration tests with Devise sign_in)
├── routing/         # 4 routing specs
├── helpers/         # 6 helper specs
├── components/      # 2 ViewComponent specs (Capybara matchers)
├── tools/           # 1 MCP tool spec (ListUserChangesTool with PaperTrail)
├── factories/       # 7 factories: user, organization, team, project, scope, task, attachment
├── rails_helper.rb  # Devise, FactoryBot, Capybara, ViewComponent, transactional fixtures
└── spec_helper.rb   # SimpleCov coverage, random order, top 10 slowest profiling
```

## Configuration
- **Devise**: `ControllerHelpers` for controller/view specs, `IntegrationHelpers` for request specs
- **FactoryBot**: `Syntax::Methods` included — use `create(:user)` not `FactoryBot.create(:user)`
- **ViewComponent**: `TestHelpers` + `Capybara::RSpecMatchers` + `url_helpers`
- **Transactional fixtures**: Enabled (each test in rolled-back transaction)
- **Coverage**: SimpleCov excludes bin/, db/, spec/

## Running
```bash
docker compose exec rails bash -lc "bundle exec rspec"                                         # All specs
docker compose exec rails bash -lc "bundle exec rspec spec/models/"                            # Category
docker compose exec rails bash -lc "bundle exec rspec spec/models/estimate_cacheable_spec.rb"  # Single file
docker compose exec rails bash -lc "bundle exec rspec --format documentation"                  # Verbose
```

## Conventions
- Factories define minimal valid records with sensible defaults
- User factory pre-confirms: `confirmed_at: Time.current`, `confirmation_token: SecureRandom.hex`
- Request specs: `sign_in(user)` from Devise IntegrationHelpers before requests
- MCP tool specs: set up PaperTrail audit data, test with `server_context[:user]`
- ViewComponent specs: use `render_inline(Component.new(...))` + Capybara `have_css` matchers
- No shared examples, custom matchers, or system tests
- Many specs are pending/scaffold — expand when modifying related code
