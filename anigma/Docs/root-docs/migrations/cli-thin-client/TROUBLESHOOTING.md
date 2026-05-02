# Troubleshooting Guide

## Quick Diagnosis

```bash
# Run comprehensive diagnostic
anigma diagnose --all

# Check specific component
anigma diagnose --component migration
anigma diagnose --component daemon
anigma diagnose --component network
```

## Common Issues and Solutions

### 1. Daemon Connection Issues

#### Symptoms
- `Error: Daemon unavailable`
- `Error: Connection refused`
- Slow response times
- Intermittent connectivity

#### Solutions

**Check Daemon Status**
```bash
# Verify daemon is running
anigma daemon-status

# Check daemon process
ps aux | grep anigmad

# Check daemon logs
anigmad logs --tail 100
```

**Start/Restart Daemon**
```bash
# Start daemon
anigmad start

# Restart daemon
anigmad restart

# Start with debug logging
ANIGMA_DEBUG=1 anigmad start --foreground
```

**Check Socket Permissions**
```bash
# Check socket file
ls -la /tmp/anigma-daemon.sock

# Fix permissions (if needed)
sudo chmod 777 /tmp/anigma-daemon.sock
```

**Network Configuration**
```bash
# Test connectivity
curl --unix-socket /tmp/anigma-daemon.sock http://localhost/health

# Check firewall
sudo ufw status

# Check daemon binding
anigmad config get --bind
```

### 2. Migration Failures

#### Symptoms
- Migration stuck at specific percentage
- `Error: Migration validation failed`
- Data corruption warnings
- Rollback triggered

#### Solutions

**Check Migration Status**
```bash
# Get detailed migration status
anigma migration-status --verbose

# Check migration logs
anigma migration-logs --tail 50

# View migration checkpoint
anigma migration-checkpoint
```

**Resume Migration**
```bash
# Resume from last checkpoint
anigma migrate --resume

# Skip failed component
anigma migrate --skip-component <component>

# Force retry
anigma migrate --force-retry
```

**Validate Data Integrity**
```bash
# Run integrity check
anigma validate-migration --integrity

# Compare source and target
anigma migration-diff --summary

# Repair corrupted data
anigma repair-migration --auto
```

**Free Up Resources**
```bash
# Check disk space
df -h

# Clear temporary files
anigma cleanup --temp

# Increase swap space (if needed)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 3. Performance Issues

#### Symptoms
- Slow command execution
- High memory usage
- Timeout errors
- Daemon crashes

#### Solutions

**Check System Resources**
```bash
# Monitor resource usage
anigma system-stats --continuous

# Check daemon resource limits
anigmad config get --resource-limits

# Profile command execution
anigma profile <command>
```

**Optimize Configuration**
```bash
# Tune daemon settings
anigmad config set --max-memory 8G
anigmad config set --cache-size 4G
anigmad config set --worker-threads 4

# Optimize CLI settings
anigma config set --connection-timeout 30
anigma config set --retry-attempts 3
anigma config set --batch-size 100
```

**Enable Caching**
```bash
# Enable response caching
anigma config set --enable-cache true
anigma config set --cache-ttl 300

# Clear cache if corrupted
anigma cache clear --all

# Monitor cache performance
anigma cache stats
```

### 4. Configuration Problems

#### Symptoms
- `Error: Invalid configuration`
- Missing API keys or settings
- Permission denied errors
- Inconsistent behavior

#### Solutions

**Validate Configuration**
```bash
# Check configuration syntax
anigma config validate

# Compare configurations
anigma config diff --source local --target daemon

# Export configuration for inspection
anigma config export --format json
```

**Fix Configuration Issues**
```bash
# Reset to defaults
anigma config reset --section <section>

# Migrate specific configuration
anigma config migrate --key <key>

# Repair corrupted config
anigma config repair --auto
```

**Update Credentials**
```bash
# Update API keys
anigma config set --provider.openai.api-key <new-key>

# Test credentials
anigma test-credentials --provider openai

# Rotate tokens
anigma auth rotate-token
```

### 5. File Operation Errors

#### Symptoms
- `Error: File not found`
- Permission denied on upload/download
- Corrupted file transfers
- Missing file references

#### Solutions

**Check File Permissions**
```bash
# Verify file ownership
ls -la <file-path>

# Fix permissions
chmod 644 <file-path>
chown $(whoami) <file-path>

# Check daemon user permissions
id anigmad
```

**Verify File Integrity**
```bash
# Check file hash
anigma file hash <file-path>

# Compare with daemon copy
anigma file verify <file-hash>

# Repair corrupted files
anigma file repair <file-hash>
```

**Troubleshoot Upload/Download**
```bash
# Test file transfer
anigma file test-transfer --size 1M

# Monitor transfer progress
anigma file transfer-progress <transfer-id>

# Resume failed transfer
anigma file resume-transfer <transfer-id>
```

### 6. Database Issues

#### Symptoms
- `Error: Database locked`
- Migration data mismatch
- Slow database queries
- Corruption warnings

#### Solutions

**Check Database Health**
```bash
# Run database integrity check
anigma database integrity-check

# Optimize database
anigma database optimize

# Backup database
anigma database backup --output backup.sql
```

**Fix Database Problems**
```bash
# Repair corrupted database
anigma database repair --auto

# Rebuild indexes
anigma database rebuild-indexes

# Vacuum database
anigma database vacuum
```

**Monitor Database Performance**
```bash
# Show slow queries
anigma database slow-queries --limit 10

# Check query plans
anigma database explain-query <query>

# Monitor database size
anigma database stats
```

## Error Code Reference

### Daemon Errors (Dxxx)
| Code | Description | Solution |
|------|-------------|----------|
| D001 | Daemon not running | Start daemon with `anigmad start` |
| D002 | Connection refused | Check socket permissions and firewall |
| D003 | Authentication failed | Run `anigma init` to re-authenticate |
| D004 | Insufficient permissions | Request additional scopes from admin |
| D005 | Rate limited | Wait and retry, reduce request frequency |

### Migration Errors (Mxxx)
| Code | Description | Solution |
|------|-------------|----------|
| M001 | Migration already in progress | Wait or use `--resume` flag |
| M002 | Insufficient disk space | Free up space or specify alternate location |
| M003 | Data validation failed | Run `anigma validate-migration --repair` |
| M004 | Rollback required | Automatic rollback triggered, check logs |
| M005 | Configuration conflict | Resolve manually with `anigma config diff` |

### Configuration Errors (Cxxx)
| Code | Description | Solution |
|------|-------------|----------|
| C001 | Invalid configuration format | Run `anigma config validate` |
| C002 | Missing required key | Check documentation for required settings |
| C003 | Permission denied | Check file permissions on config files |
| C004 | Version mismatch | Update CLI or daemon to compatible versions |
| C005 | Circular reference | Review configuration dependencies |

### File Errors (Fxxx)
| Code | Description | Solution |
|------|-------------|----------|
| F001 | File not found | Verify file path and permissions |
| F002 | Upload failed | Check network and storage availability |
| F003 | Download failed | Verify file exists in daemon vault |
| F004 | Hash mismatch | File corrupted during transfer, retry |
| F005 | Storage quota exceeded | Clean up old files or increase quota |

## Diagnostic Commands

### Comprehensive Diagnostics
```bash
# Run full diagnostic suite
anigma diagnose --all --output diagnostic-report.json

# Test specific functionality
anigma test --component chat
anigma test --component file-transfer
anigma test --component database

# Generate support bundle
anigma support-bundle --include-logs --include-config
```

### Network Diagnostics
```bash
# Test daemon connectivity
anigma network-test --daemon

# Check DNS resolution
anigma network-test --dns

# Test upload/download speed
anigma network-test --bandwidth

# Check latency
anigma network-test --latency
```

### Performance Diagnostics
```bash
# Profile command execution
anigma profile "models list" --output profile.json

# Monitor resource usage
anigma monitor --duration 60 --interval 5

# Identify bottlenecks
anigma bottleneck-detect --command <command>
```

## Recovery Procedures

### Complete System Recovery
```bash
# 1. Stop all services
anigmad stop
pkill -f anigma

# 2. Restore from backup
anigma restore --backup <backup-file> --full

# 3. Verify restoration
anigma verify-restoration

# 4. Start services
anigmad start
anigma status
```

### Partial Recovery
```bash
# Restore configuration only
anigma restore --backup <backup-file> --config-only

# Restore database only
anigma restore --backup <backup-file> --database-only

# Restore files only
anigma restore --backup <backup-file> --files-only
```

### Emergency Rollback
```bash
# List available rollback points
anigma rollback-list

# Execute rollback
anigma rollback --to <timestamp>

# Verify rollback
anigma verify-rollback
```

## Log Analysis

### Finding Relevant Logs
```bash
# Search for errors
grep -i error ~/.anigma/logs/*.log

# Search for specific component
grep -i migration ~/.anigma/logs/*.log

# Tail live logs
tail -f ~/.anigma/logs/daemon.log
```

### Understanding Log Messages
```bash
# Parse structured logs
anigma logs parse --file ~/.anigma/logs/daemon.log --format json

# Filter by severity
anigma logs filter --level error --limit 50

# Generate log summary
anigma logs summary --period 24h
```

### Debug Mode
```bash
# Enable debug logging
export ANIGMA_DEBUG=1

# Run command with debug output
anigma --debug <command>

# Capture debug output to file
anigma --debug <command> 2>&1 | tee debug.log
```

## Prevention Best Practices

### Regular Maintenance
```bash
# Weekly maintenance tasks
anigma maintenance --weekly

# Monthly optimization
anigma optimize --monthly

# Quarterly cleanup
anigma cleanup --quarterly
```

### Monitoring Setup
```bash
# Enable health checks
anigma monitor enable --health-checks

# Set up alerts
anigma alert configure --critical-errors
anigma alert configure --performance-degradation
anigma alert configure --resource-usage

# Schedule regular reports
anigma report schedule --daily --email <email>
```

### Backup Strategy
```bash
# Configure automatic backups
anigma backup configure --frequency daily --retention 30

# Test backup restoration
anigma backup test-restore --latest

# Monitor backup success
anigma backup monitor --alerts
```

## Getting Support

### Prepare Support Information
```bash
# Generate support package
anigma support-package --include-all

# Expected output includes:
# - System information
# - Configuration files
# - Recent logs
# - Error reports
# - Performance metrics
```

### Contact Information
- **Documentation**: https://docs.anigma.ai/troubleshooting
- **Community Forums**: https://community.anigma.ai
- **Support Email**: support@anigma.ai
- **Emergency**: emergency@anigma.ai (critical issues only)

### What to Include
1. Error messages and codes
2. Steps to reproduce
3. System information
4. Relevant logs
5. Support package output

---

**Last Updated**: 2026-01-27  
**Troubleshooting Version**: 3.0.0  
**Support SLA**: 24-hour response for critical issues