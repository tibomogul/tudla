# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

3.3.4

* System dependencies

* Configuration

* Database creation and initialization

`docker compose exec rails bin/setup`

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Deployment

Buidling the production docker image
```
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

## Backup and Restore

The production environment includes automated daily backups of:
- PostgreSQL database (compressed dumps)
- Active Storage files (uploaded attachments)

**Quick Start:**
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

**Documentation:**
- Full guide: [docs/backup_and_restore.md](docs/backup_and_restore.md)
- Quick reference: [docs/backup_quick_reference.md](docs/backup_quick_reference.md)

**Configuration:**
- Default schedule: Daily at 2:00 AM
- Default retention: 7 days
- Customize via `BACKUP_RETENTION_DAYS` in `.env`