# Backup and Restore Documentation

This document describes the automated backup system for the production environment.

## Overview

The backup system automatically backs up:
- **PostgreSQL Databases**: All configured databases for the environment (primary, queue, cable, cache)
- **Active Storage Files**: All uploaded files and attachments

Each database is backed up individually, allowing for granular restore operations.

Backups run **daily at 2:00 AM** server time and are retained for **7 days** by default.

## Architecture

- **Backup Service**: Dedicated Docker container running cron jobs
- **Backup Storage**: Named volume `backups_production` mounted at `/backups`
- **Backup Scripts**: 
  - `bin/backup` - Performs backups
  - `bin/restore` - Restores from backups

## Configuration

### Environment Variables

Add to your `.env` file:

```bash
# Backup retention in days (default: 7)
BACKUP_RETENTION_DAYS=7
```

### Backup Schedule

The default schedule is **daily at 2:00 AM**. To change this, modify the cron expression in `compose-production.yml`:

```yaml
# Current: 0 2 * * * (2:00 AM daily)
# Format: minute hour day month weekday
echo '0 2 * * * /home/user/app/bin/backup >> /var/log/backup.log 2>&1' | crontab -
```

Examples:
- `0 3 * * *` - 3:00 AM daily
- `0 2 * * 0` - 2:00 AM every Sunday
- `0 */6 * * *` - Every 6 hours

## Usage

### Starting the Backup Service

```bash
docker compose -f compose-production.yml up -d backup
```

### Manual Backup

Run a backup immediately:

```bash
docker compose -f compose-production.yml exec backup /home/user/app/bin/backup
```

### View Backup Logs

```bash
docker compose -f compose-production.yml logs -f backup
```

### List Available Backups

```bash
# List all backups
docker compose -f compose-production.yml exec backup ls -lh /backups/database
docker compose -f compose-production.yml exec backup ls -lh /backups/storage

# Or use the restore script to see available timestamps
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore
```

### Restore from Backup

1. **List available backups:**
```bash
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore
```

2. **Restore from a specific backup:**
```bash
# Format: YYYYMMDD_HHMMSS
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore 20240315_120000
```

3. **Restart Rails application:**
```bash
docker compose -f compose-production.yml restart rails queue
```

### Download Backups to Local Machine

```bash
# Create local backup directory
mkdir -p ~/backups/task_manager

# Copy database backups
docker compose -f compose-production.yml cp backup:/backups/database ~/backups/task_manager/

# Copy storage backups
docker compose -f compose-production.yml cp backup:/backups/storage ~/backups/task_manager/
```

### Upload Backups to Remote Storage (Optional)

You can sync backups to S3, Google Cloud Storage, or other remote storage:

```bash
# Example: Sync to AWS S3 (requires AWS CLI in backup container)
docker compose -f compose-production.yml exec backup \
  aws s3 sync /backups s3://your-bucket/task-manager-backups/
```

## Backup Contents

### Database Backups (`DBNAME_TIMESTAMP.dump.gz`)
- Format: PostgreSQL custom dump format (compressed with gzip)
- Naming: `{database_name}_{timestamp}.dump.gz` (e.g., `task_manager_production_20240315_120000.dump.gz`)
- Contains: Complete database schema and data for each database
- Databases backed up (production):
  - `task_manager_production` - Primary application data
  - `task_manager_production_queue` - Solid Queue background jobs
  - `task_manager_production_cable` - Solid Cable WebSocket messages
  - `task_manager_production_cache` - Solid Cache data
- Size: ~10-100MB per database (depends on data size)

### Storage Backup (`storage_TIMESTAMP.tar.gz`)
- Format: Compressed tar archive
- Contains: All files in `storage/` directory
- Includes: Active Storage attachments, cache, uploads
- Size: Varies based on uploaded files

## Monitoring

### Check Backup Status

```bash
# View last backup log
docker compose -f compose-production.yml exec backup tail -100 /var/log/backup.log

# Check disk usage
docker compose -f compose-production.yml exec backup df -h /backups

# List backup files with sizes
docker compose -f compose-production.yml exec backup du -sh /backups/*
```

### Verify Backups

It's recommended to periodically verify backups by:
1. Restoring to a test environment
2. Checking data integrity
3. Testing application functionality

## Retention Policy

- Default retention: **7 days**
- Automatic cleanup runs after each backup
- Older backups are automatically deleted
- Modify `BACKUP_RETENTION_DAYS` to change retention

## Disaster Recovery

### Complete System Recovery

1. **Set up new environment:**
```bash
# Deploy fresh Docker Compose setup
docker compose -f compose-production.yml up -d db
```

2. **Copy backup volume from old system** (if accessible):
```bash
docker volume create backups_production
# Copy backup files to volume
```

3. **Or restore from downloaded backups:**
```bash
# Copy backups into the backup container (all database files for the timestamp)
docker compose -f compose-production.yml cp ~/backups/task_manager/database/task_manager_production_20240315_120000.dump.gz backup:/backups/database/
docker compose -f compose-production.yml cp ~/backups/task_manager/database/task_manager_production_queue_20240315_120000.dump.gz backup:/backups/database/
docker compose -f compose-production.yml cp ~/backups/task_manager/database/task_manager_production_cable_20240315_120000.dump.gz backup:/backups/database/
docker compose -f compose-production.yml cp ~/backups/task_manager/database/task_manager_production_cache_20240315_120000.dump.gz backup:/backups/database/
docker compose -f compose-production.yml cp ~/backups/task_manager/storage/storage_20240315_120000.tar.gz backup:/backups/storage/
```

4. **Restore:**
```bash
docker compose -f compose-production.yml exec backup /home/user/app/bin/restore 20240315_120000
```

5. **Start all services:**
```bash
docker compose -f compose-production.yml up -d
```

## Troubleshooting

### Backup Service Not Running

```bash
# Check service status
docker compose -f compose-production.yml ps backup

# View logs
docker compose -f compose-production.yml logs backup

# Restart service
docker compose -f compose-production.yml restart backup
```

### Backup Failed

```bash
# Check logs
docker compose -f compose-production.yml logs backup

# Common issues:
# - Insufficient disk space
# - Database connection issues
# - Permission problems
```

### Restore Failed

```bash
# Check if backup files exist
docker compose -f compose-production.yml exec backup ls -l /backups/database/

# Verify database connection
docker compose -f compose-production.yml exec backup \
  bash -c 'PGPASSWORD=$DATABASE_PASSWORD psql -h $DATABASE_HOST -U postgres -c "\l"'
```

### Disk Space Issues

```bash
# Check available space
docker compose -f compose-production.yml exec backup df -h

# Reduce retention period
# Edit .env: BACKUP_RETENTION_DAYS=3

# Manually clean old backups
docker compose -f compose-production.yml exec backup \
  find /backups -name "*.gz" -mtime +3 -delete
```

## Security Considerations

1. **Backup Volume**: The `backups_production` volume contains sensitive data
2. **Access Control**: Restrict access to backup containers and volumes
3. **Encryption**: Consider encrypting backups at rest
4. **Off-site Storage**: Store copies in a separate location/region
5. **Database Password**: Ensure `DATABASE_PASSWORD` is properly secured

## Best Practices

1. **Test Restores**: Regularly test backup restoration in a staging environment
2. **Monitor Disk Usage**: Set up alerts for backup volume disk usage
3. **Off-site Backups**: Regularly copy backups to remote storage
4. **Document Recovery**: Keep disaster recovery documentation up to date
5. **Backup Validation**: Periodically verify backup integrity
6. **Access Logs**: Monitor who accesses backup data

## Support

For issues or questions about the backup system, refer to:
- Application logs: `docker compose -f compose-production.yml logs backup`
- Backup scripts: `bin/backup` and `bin/restore`
- This documentation: `docs/backup_and_restore.md`
