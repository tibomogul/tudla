# Tudla

> Tudlâ - Filipino word for act or manner of shooting or hitting a target (with a gun, arrow, spear, etc.)

A modern task management application built with Ruby on Rails 8, designed for small teams practicing the [Shape Up](https://basecamp.com/shapeup) methodology. Organize projects into scopes, track tasks through simple workflows, and collaborate effectively with real-time updates.

[![Ruby](https://img.shields.io/badge/Ruby-3.3.4-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-blue.svg)](https://www.postgresql.org/)

## Features

- **Task Management** - Create, assign, and track tasks with state machine workflows
- **Project Organization** - Organize work into projects with scopes and risk tracking
- **Team Collaboration** - Multi-tenant organization and team structure
- **Real-time Updates** - Live updates via Turbo Streams and ActionCable
- **Analytics** - Cycle time tracking and per-user analytics
- **Slack Integration** - Post reports and updates to Slack channels
- **MCP Integration** - Model Context Protocol support via fast-mcp gem
- **Audit Trail** - Full history tracking with PaperTrail

## Roadmap

Planned features to further support the Shape Up methodology:

- **Shaping Track** - A dedicated space for rough, private work on potential projects before they're ready to bet on. Shapers can sketch ideas, identify risks, and define boundaries without committing the team.
- **Betting Table** - Formalize the betting process where stakeholders review shaped pitches and decide what to build in the next cycle. Track bets, appetites, and cycle commitments.
- **Cycle Management** - Define and manage six-week cycles with cooldown periods. Visualize what's being built vs. what's being shaped across [two parallel tracks](https://basecamp.com/shapeup/1.1-chapter-02#two-tracks).
- **Pitches** - Create and manage pitches with problem definitions, appetite, solution sketches, rabbit holes, and no-gos.

## Tech Stack

- **Framework**: Ruby on Rails 8.1
- **Database**: PostgreSQL 18
- **Frontend**: Tailwind CSS, Hotwire (Turbo + Stimulus), Importmap
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable
- **State Machine**: Statesman
- **Authorization**: Pundit
- **Authentication**: Devise with OAuth (Google, Microsoft)
- **Containerization**: Docker Compose

## Requirements

- Docker and Docker Compose
- Git

## Docker Development Environment

The Dockerfile is designed for an optimal developer experience:

- **Volume Mapping with Correct Permissions** - Configure `DOCKER_UID` and `DOCKER_GID` to match your host user, ensuring seamless file permissions when mounting the project directory
- **Sudo Access in Development** - Development containers include passwordless sudo for installing additional packages or debugging (disabled in production builds)
- **SSH Agent Forwarding** - Mount your host's SSH socket to access private Git repositories from within the container without copying keys
- **Pre-installed Tools** - Includes rbenv, nvm, PostgreSQL client, Redis, and common development utilities

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/tibomogul/tudla.git
cd tudla
```

### 2. Configure environment variables

Create a `.env` file in the project root. See the [Environment Variables](#environment-variables) section for the full reference. At minimum for development:

```bash
# Docker configuration (required)
DOCKER_UID=1000
DOCKER_GID=1000
DOCKER_SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock

# Git configuration (required for commits inside container)
GIT_COMMITTER_NAME="Your Name"
GIT_COMMITTER_EMAIL="your.email@example.com"
```

### 3. Start the application

```bash
# Start Docker containers
docker compose up -d

# Get into the container
docker compose exec rails bash -l 

# Set up the database
$ bin/setup

# Start the development server
$ bin/dev
```

### 4. Access the application

- **Application**: http://localhost:3000
- **Mailcatcher**: http://localhost:1080 (for development emails)

## Development

### Running Tests

```bash
# Run all specs
docker compose exec rails bundle exec rspec

# Run specific spec file
docker compose exec rails bundle exec rspec spec/models/task_spec.rb

# Run with verbose output
docker compose exec rails bundle exec rspec --format documentation
```

### Code Quality

```bash
# Run RuboCop linter
docker compose exec rails bundle exec rubocop

# Run Brakeman security scanner
docker compose exec rails bundle exec brakeman
```

### Database Commands

```bash
# Reset database (drops, creates, migrates, seeds)
docker compose exec rails bin/rails db:reset

# Run pending migrations
docker compose exec rails bin/rails db:migrate

# Open Rails console
docker compose exec rails bin/rails console
```

## Project Structure

```
app/
├── controllers/          # Request handling
├── models/              # ActiveRecord models & state machines
├── views/               # ERB templates
├── policies/            # Pundit authorization policies
├── state_machines/      # Statesman state machine definitions
├── services/            # Business logic services
└── javascript/          # Stimulus controllers

config/
├── routes.rb            # URL routing
├── database.yml         # Multi-database configuration
└── environments/        # Environment-specific settings

db/
├── schema.rb            # Primary database schema
├── queue_schema.rb      # Solid Queue schema
└── cable_schema.rb      # Solid Cable schema

docs/                    # Additional documentation
spec/                    # RSpec tests
```

## Deployment

### Building the production Docker image

```bash
export CURRENT_COMMIT=$(git rev-parse HEAD)
docker build . \
  --platform linux/amd64 \
  --build-arg TARGETARCH=linux/amd64 \
  --build-arg RAILS_ENV=production \
  --build-arg build_docker_uid=$DOCKER_UID \
  --build-arg build_docker_gid=$DOCKER_GID \
  --build-arg build_timezone=Australia/Brisbane \
  -t tibomogul/tudla:$CURRENT_COMMIT
```

### Production deployment

```bash
docker compose -f compose-production.yml up -d
```

## Backup and Restore

The production environment includes automated daily backups of:
- PostgreSQL database (compressed dumps)
- Active Storage files (uploaded attachments)

### Quick commands

```bash
# Start backup service
docker compose -f compose-production.yml up -d backup

# Manual backup
docker compose -f compose-production.yml exec backup /home/user/app/bin/backup

# List available backups
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore

# Restore from backup
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore 20240315_120000
```

### Configuration

| Setting | Default | Environment Variable |
|---------|---------|---------------------|
| Schedule | Daily at 2:00 AM | `BACKUP_SCHEDULE` |
| Retention | 7 days | `BACKUP_RETENTION_DAYS` |

For detailed backup documentation, see:
- [Full guide](docs/backup_and_restore.md)
- [Quick reference](docs/backup_quick_reference.md)

## Environment Variables

All environment variables used by the application, organized by category. Create a `.env` file in the project root for Docker Compose to pick up.

### Docker & Build

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `DOCKER_UID` | Yes | Development | — | Host user ID for correct file permissions in volume mounts |
| `DOCKER_GID` | Yes | Development | — | Host group ID for correct file permissions in volume mounts |
| `DOCKER_SSH_AUTH_SOCK` | Yes | Development | — | Path to host SSH auth socket for agent forwarding |
| `GIT_COMMITTER_NAME` | Yes | Development | — | Git committer name inside the container |
| `GIT_COMMITTER_EMAIL` | Yes | Development | — | Git committer email inside the container |
| `CURRENT_COMMIT` | Yes | Production | — | Git SHA used to tag the Docker image for deployment |
| `HOST_PORT` | Yes | Production | — | Host port mapped to the Rails container (e.g. `3000`) |

### Database

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `DATABASE_HOST` | No | All | `localhost` | PostgreSQL host (set to `db` by Docker Compose) |
| `DATABASE_PASSWORD` | Yes | Production | — | PostgreSQL password (development defaults to `postgres`) |
| `RAILS_MAX_THREADS` | No | All | `5` (db) / `3` (puma) | Database connection pool size and Puma thread count |

### Rails

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `RAILS_ENV` | No | All | `development` | Rails environment (`development`, `test`, `production`) |
| `RAILS_LOG_LEVEL` | No | Production | `info` | Log level (`debug`, `info`, `warn`, `error`, `fatal`) |
| `SECRET_KEY_BASE` | Yes | Production | — | Secret key for session cookies and encryption |
| `PORT` | No | All | `3000` | Port Puma listens on |
| `PIDFILE` | No | All | — | Custom PID file path for Puma |

### ActionCable (WebSockets)

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `ACTION_CABLE_ALLOWED_ORIGIN` | Yes | Production | — | Production domain for WebSocket origin checking (e.g. `tudla.example.com`) |

### Email (SMTP)

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `ACTION_MAILER_ADDRESS` | No | Production | `127.0.0.1` | SMTP server address. If unset, defaults to localhost (Mailcatcher in dev) |
| `ACTION_MAILER_PORT` | No | Production | `1025` | SMTP server port |
| `ACTION_MAILER_USERNAME` | No | Production | — | SMTP authentication username |
| `ACTION_MAILER_PASSWORD` | No | Production | — | SMTP authentication password |
| `ACTION_MAILER_DEFAULT_FROM` | No | All | `from@example.com` | Default "From" address for outgoing emails |
| `ACTION_MAILER_DEFAULT_URL_OPTIONS_HOST` | Yes | Production | — | Host used in mailer URL generation (e.g. `tudla.example.com`) |

### Authentication (OAuth)

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `GOOGLE_CLIENT_ID` | No | All | — | Google OAuth 2.0 client ID |
| `GOOGLE_CLIENT_SECRET` | No | All | — | Google OAuth 2.0 client secret |
| `AZURE_APPLICATION_CLIENT_ID` | No | All | — | Microsoft Azure AD client ID |
| `AZURE_APPLICATION_CLIENT_SECRET` | No | All | — | Microsoft Azure AD client secret |
| `NEW_OAUTH_USER_STRATEGY` | No | All | — | Set to `CREATE` to auto-create users on first OAuth login |

### Account & UI

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `ACCOUNT_SIGNUP_ENABLED` | No | All | — | Set to `YES` to show the sign-up link on the login page |
| `ACCOUNT_REQUIRE_TERMS_AND_CONDITIONS` | No | All | — | Set to `YES` to require T&C acceptance at login |

### Background Jobs (Solid Queue)

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `JOB_CONCURRENCY` | No | All | `1` | Number of Solid Queue worker processes |
| `SOLID_QUEUE_IN_PUMA` | No | Production | — | Set to run Solid Queue supervisor inside Puma (single-server deployments) |

### Slack Integration

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `SLACK_WEBHOOK` | No | All | — | Slack incoming webhook URL for report delivery |
| `SLACK_CHANNEL` | No | All | — | Slack channel for report delivery |
| `SLACK_BOT_TOKEN` | No | All | — | Slack Bot token (alternative to webhook, see [Slack docs](docs/slack_integration.md)) |

### Backup

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `BACKUP_RETENTION_DAYS` | No | Production | `7` | Number of days to retain backup files |
| `BACKUP_SCHEDULE` | No | Production | Daily at 2:00 AM | Cron schedule for automated backups |

### Testing & CI

| Variable | Required | Environment | Default | Description |
|----------|----------|-------------|---------|-------------|
| `CI` | No | Test | — | Set by CI systems; enables eager loading in test environment |

## Documentation

Additional documentation is available in the `docs/` directory:

- [Slack Integration](docs/slack_integration.md)
- [MCP Setup](docs/mcp_setup.md)
- [Timezone Handling](docs/timezone_handling.md)
- [Soft Delete Implementation](docs/soft_delete.md)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development guidelines

- Follow the existing code style (enforced by RuboCop)
- Write tests for new features
- Update documentation as needed
- Keep commits atomic and well-described

## License

This project is licensed under the [O'Saasy License](https://osaasy.dev/). See the [LICENSE](LICENSE) file for details.

This means:
- You can use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software
- You must include the copyright notice and permission notice in all copies
- You may not use the Software to directly compete with the original Licensor by offering it as a SaaS product where the primary value is the functionality of the Software itself

## Acknowledgments

Built with these excellent open source projects:
- [Ruby on Rails](https://rubyonrails.org/)
- [Hotwire](https://hotwired.dev/)
- [Tailwind CSS](https://tailwindcss.com/)
- [DaisyUI](https://daisyui.com/)
- [Statesman](https://github.com/gocardless/statesman)
- [Pundit](https://github.com/varvet/pundit)
- [Devise](https://github.com/heartcombo/devise)