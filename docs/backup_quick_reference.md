# Backup Quick Reference

Quick commands for common backup operations.

> **Note**: The backup system handles multiple databases (primary, queue, cable, cache). Each database is backed up as `{db_name}_{timestamp}.dump.gz`.

## Setup

```bash
# Start backup service
docker compose -f compose-production.yml up -d backup

# View backup logs
docker compose -f compose-production.yml logs -f backup
```

## Backup Operations

```bash
# Manual backup (immediate)
docker compose -f compose-production.yml exec backup /home/user/app/bin/backup

# List database backups
docker compose -f compose-production.yml exec backup ls -lh /backups/database

# List storage backups
docker compose -f compose-production.yml exec backup ls -lh /backups/storage

# Check disk usage
docker compose -f compose-production.yml exec backup du -sh /backups
```

## Restore Operations

```bash
# List available backup timestamps
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore

# Restore all databases from specific timestamp
# (restores: primary, queue, cable, cache databases)
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore 20240315_120000

# Restart application after restore
docker compose -f compose-production.yml restart rails queue
```

## Download Backups

```bash
# Download to local machine
mkdir -p ~/backups/task_manager
docker compose -f compose-production.yml cp backup:/backups/database ~/backups/task_manager/
docker compose -f compose-production.yml cp backup:/backups/storage ~/backups/task_manager/
```

## Configuration

```bash
# Edit retention period in .env
BACKUP_RETENTION_DAYS=7

# Restart backup service to apply changes
docker compose -f compose-production.yml restart backup
```

## Monitoring

```bash
# View last 100 log lines
docker compose -f compose-production.yml exec backup tail -100 /var/log/backup.log

# Check service status
docker compose -f compose-production.yml ps backup

# Monitor disk space
docker compose -f compose-production.yml exec backup df -h /backups
```

## Troubleshooting

```bash
# View full logs
docker compose -f compose-production.yml logs backup

# Restart backup service
docker compose -f compose-production.yml restart backup

# Clean up old backups manually (older than 3 days)
docker compose -f compose-production.yml exec backup \
  find /backups -name "*.gz" -mtime +3 -delete
```

## Backup Schedule

Default: **Daily at 2:00 AM** server time

Modify in `compose-production.yml`:
```yaml
echo '0 2 * * * /home/user/app/bin/backup >> /var/log/backup.log 2>&1' | crontab -
```

Common schedules:
- `0 3 * * *` - 3:00 AM daily
- `0 2 * * 0` - 2:00 AM every Sunday
- `0 */6 * * *` - Every 6 hours
- `0 0 * * *` - Midnight daily
