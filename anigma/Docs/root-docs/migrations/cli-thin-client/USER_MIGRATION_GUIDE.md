# User Migration Guide

## Overview

This guide walks you through migrating from the standalone Anigma CLI to the new thin client architecture. The migration process is designed to be safe, incremental, and reversible.

## Prerequisites

### System Requirements
- **Anigma CLI**: Version 2.0 or higher
- **Anigma Daemon**: Version 1.5 or higher
- **Disk Space**: At least 2GB free for migration data
- **Memory**: 4GB RAM minimum, 8GB recommended

### Before You Begin
1. **Backup Important Data**
   ```bash
   # Backup CLI configuration
   anigma backup-config --output ~/anigma-backup-$(date +%Y%m%d).tar.gz
   
   # Backup database (if applicable)
   anigma backup-database --output ~/anigma-db-backup.sql
   ```

2. **Check Current Version**
   ```bash
   anigma --version
   anigmad --version  # If daemon is installed
   ```

3. **Verify System Health**
   ```bash
   anigma system-check
   ```

## Migration Process

### Step 1: Install or Update Daemon

#### Option A: Install New Daemon
```bash
# Download and install daemon
curl -fsSL https://get.anigma.ai/daemon | bash

# Start daemon
anigmad start

# Enable auto-start
anigmad enable
```

#### Option B: Update Existing Daemon
```bash
# Stop current daemon
anigmad stop

# Update daemon
anigmad update

# Start updated daemon
anigmad start
```

### Step 2: Check Migration Readiness

```bash
# Check if migration is needed
anigma migration-status

# Expected output:
# ✅ Daemon is running (version 1.5.2)
# ⚠️  Configuration migration available
# ⚠️  Database migration available
# 📊 Estimated migration time: 5-10 minutes
```

### Step 3: Start Migration

#### Interactive Migration (Recommended)
```bash
# Start interactive migration wizard
anigma migrate

# Follow the prompts:
# 1. Review migration plan
# 2. Confirm backup creation
# 3. Start migration
# 4. Monitor progress
# 5. Verify results
```

#### Automated Migration
```bash
# Run migration with default options
anigma migrate --auto --backup --verify

# Monitor progress
anigma migration-progress

# Check status
anigma migration-status
```

### Step 4: Verify Migration

```bash
# Run comprehensive verification
anigma verify-migration --full

# Expected output:
# ✅ Configuration migrated (142/142 keys)
# ✅ Database migrated (15,328 records)
# ✅ File references updated (847 files)
# ✅ Permissions synchronized
# ✅ Performance baseline established
```

### Step 5: Test Functionality

```bash
# Test basic commands
anigma status
anigma models list
anigma chat "Hello, test migration"

# Test file operations
echo "Test content" > test.txt
anigma analyze test.txt

# Test job submission
anigma plan "Create a simple Swift function"
```

## Migration Components

### 1. Configuration Migration

#### What Gets Migrated
- **Provider configurations** (API keys, endpoints)
- **Model preferences** (default models, parameters)
- **Output settings** (format, colors, verbosity)
- **Workspace settings** (paths, exclusions)
- **Security settings** (tokens, permissions)

#### Migration Strategy
- **Hybrid mode**: CLI uses daemon config first, falls back to local
- **Conflict resolution**: User prompted for conflicts
- **Rollback**: Automatic backup created

### 2. Database Migration

#### What Gets Migrated
- **Run history** (past executions and results)
- **Step data** (individual operation details)
- **Receipts** (transaction records)
- **Leases** (resource allocations)
- **Chunks** (file fragments)
- **Embeddings** (vector data)

#### Migration Strategy
- **Incremental**: 12-phase migration with checkpoints
- **Validation**: Integrity checks at each phase
- **Rollback**: Point-in-time recovery available

### 3. File System Migration

#### What Gets Migrated
- **File references**: Paths updated to daemon vault
- **Cache data**: Transferred to daemon cache
- **Temporary files**: Cleaned up after migration

#### Migration Strategy
- **Lazy loading**: Files migrated on first access
- **Progress reporting**: Real-time transfer status
- **Resumable**: Can pause and resume migration

## Post-Migration Tasks

### 1. Clean Up Old Files (Optional)
```bash
# Remove old CLI configuration
anigma cleanup --old-config

# Remove migrated database files
anigma cleanup --old-database

# Review what will be removed
anigma cleanup --dry-run
```

### 2. Optimize Performance
```bash
# Run performance tuning
anigma optimize --all

# Set up monitoring
anigma monitor setup

# Configure alerts
anigma alert configure
```

### 3. Update Automation Scripts
```bash
# Update scripts to use new CLI syntax
# Old: anigma --local analyze file.txt
# New: anigma analyze file.txt  # Uses daemon automatically
```

## Troubleshooting Common Issues

### Issue: Daemon Not Running
```bash
# Check daemon status
anigma daemon-status

# Start daemon if stopped
anigmad start

# Check logs for errors
anigmad logs --tail 50
```

### Issue: Migration Stuck
```bash
# Check migration progress
anigma migration-progress --detailed

# Resume migration
anigma migrate --resume

# Reset migration state (if needed)
anigma migrate --reset
```

### Issue: Performance Degradation
```bash
# Check system resources
anigma system-stats

# Tune daemon settings
anigmad config set --max-memory 8G
anigmad config set --cache-size 4G

# Restart daemon with new settings
anigmad restart
```

## Rollback Procedure

### Automatic Rollback
```bash
# If migration fails, automatic rollback occurs
# Check rollback status
anigma rollback-status

# Manual rollback trigger
anigma rollback --to-backup <backup-id>
```

### Manual Recovery
```bash
# Restore from backup
anigma restore --backup ~/anigma-backup.tar.gz

# Revert configuration
anigma config reset --to-pre-migration

# Restart with old CLI
ANIGMA_USE_DAEMON=false anigma status
```

## Migration Safety Features

### 1. Automatic Backups
- Configuration backed up before migration
- Database snapshots at each phase
- File system state preserved

### 2. Validation Checks
- Pre-migration system check
- Mid-migration integrity verification
- Post-migration functionality test

### 3. Progress Monitoring
- Real-time progress reporting
- Estimated time remaining
- Detailed migration logs

### 4. Rollback Capability
- Automatic on failure
- Manual rollback available
- Point-in-time recovery

## Best Practices

### 1. Schedule Migration
- Perform during low-usage periods
- Allow extra time for large datasets
- Have backup administrator available

### 2. Monitor Resources
- Watch disk space during migration
- Monitor memory usage
- Check network connectivity

### 3. Test Thoroughly
- Test all critical workflows
- Verify data integrity
- Check performance benchmarks

### 4. Document Changes
- Record migration start/end times
- Note any issues encountered
- Document configuration changes

## Migration Complete Checklist

- [ ] Daemon installed and running
- [ ] Configuration migrated successfully
- [ ] Database migrated with integrity
- [ ] File references updated
- [ ] All commands tested
- [ ] Performance verified
- [ ] Backups validated
- [ ] Documentation updated
- [ ] Team notified of changes

## Getting Help

### Migration Support
```bash
# Generate migration report for support
anigma migration-report --detailed --output migration-report.json

# Check known issues
anigma migration-known-issues

# Get help with specific error
anigma help migration-error <error-code>
```

### Community Resources
- **Documentation**: https://docs.anigma.ai/migration
- **Forums**: https://community.anigma.ai
- **Support**: support@anigma.ai

---

**Migration Version**: 3.0.0  
**Last Updated**: 2026-01-27  
**Support Period**: 90 days post-migration