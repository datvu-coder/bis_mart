# Production Deployment Checklist - Bismart PostgreSQL Migration

## CRITICAL FIX: Data Loss Bug Resolution

**Issue**: Sales reports (báo cáo) and attendance records (chấm công) were disappearing after creation under concurrent load.

**Root Cause**: Unsafe `lastrowid + SELECT * ORDER BY id DESC LIMIT 1` race condition
- Multiple concurrent POST requests could interfere with ID retrieval
- Report A's INSERT would fetch Report B's ID
- Sale items would insert into the wrong report

**Solution**: Atomic `RETURNING id` for all INSERT operations
- Each INSERT now atomically returns its own ID
- No possibility of race conditions
- PostgreSQL-only backend (no SQLite fallback)

---

## Deployment Steps

### Phase 1: Pre-Deployment Verification (✓ COMPLETED)

- [x] **Backend Code Changes**
  - [x] app.py converted to PostgreSQL-only
  - [x] Removed SQLite references (sqlite3, DATABASE_PATH, DATABASE_DIR)
  - [x] Added 4 atomic `RETURNING *` clauses to critical INSERTs
  - [x] All SQL placeholders changed from `?` to `%s` (PostgreSQL style)
  - [x] Syntax validated: `python3 -m py_compile backend/app.py` ✓
  - [x] File imports verified: No flask_cors, no sqlite3 ✓

- [x] **Docker Configuration**
  - [x] Removed SQLite env vars from Dockerfile
  - [x] Removed `/data` VOLUME declaration
  - [x] Optimized Gunicorn workers (2 workers, 1 thread each)

- [x] **Git Repository**
  - [x] Commit 0225b87: "CRITICAL FIX: PostgreSQL-only backend with atomic RETURNING id"
  - [x] Commit ba688f0: "Dockerfile: Remove SQLite env vars and VOLUME"
  - [x] Commit 9ccaaab: "Add comprehensive production smoke test suite"
  - [x] All pushed to GitHub (main branch)

### Phase 2: Coolify Deployment (⏳ IN PROGRESS)

**Prerequisites:**
- [ ] Verify production .env has DATABASE_URL set:
  ```
  DATABASE_URL=postgresql://bismart:BismartPassword2024@bismart-postgres:5432/bismart
  ```
- [ ] Verify PostgreSQL container is running:
  ```bash
  ssh root@146.196.64.92
  docker ps | grep bismart-postgres
  ```
- [ ] Verify PostgreSQL backup is working:
  ```bash
  /opt/bismart/scripts/backup_postgres.sh
  ```

**Deployment Process:**

1. **Trigger Rebuild in Coolify** (Automatic or Manual)
   - Navigate to Coolify dashboard: `https://146.196.64.92` or your configured URL
   - Go to Application: `z3izrmiy9penrgf0bbhq020p` (bis_mart_backend)
   - Click "Redeploy" or "Rebuild" button
   - Monitor deployment logs for errors

2. **Build Process** (Expected: 2-3 minutes)
   - Coolify pulls latest code from GitHub (commit 9ccaaab)
   - Builds new Docker image with updated app.py and Dockerfile
   - Starts container with PostgreSQL DATABASE_URL from .env
   - Container ready when logs show: `Listening on 0.0.0.0:8000`

3. **Verify Container Startup**
   ```bash
   ssh root@146.196.64.92
   docker logs -f bis_mart_backend  # tail last logs
   # Should show: "Gunicorn workers started"
   ```

### Phase 3: Production Smoke Testing (✓ READY)

**Run after deployment completes:**

1. **Quick Health Check** (Minimal)
   ```bash
   curl https://your-api-domain.com/healthz
   # Expected: {"status": "ok", "backend": "postgres", "employees": N}
   ```

2. **Full Smoke Test Suite** (Comprehensive)
   ```bash
   cd backend
   pip install requests  # if not installed
   python3 smoke_test_production.py --backend https://your-api-domain.com
   ```

3. **Manual Smoke Test** (If needed)
   - **Create Report**: POST /api/reports with sample data, verify report_id in response
   - **Create Multiple Reports**: Fire 5 concurrent requests, verify all get unique IDs
   - **Verify Data**: List reports, confirm all created reports are visible
   - **Check Concurrency**: Create attendance for same employee twice, verify both recorded

### Phase 4: Rollback Plan (If Needed)

If critical issues occur:

```bash
# Option 1: Redeploy Previous Version
git log --oneline -5
# Find commit before 0225b87
git checkout <previous-commit-hash>
git push origin <previous-commit-hash>:main
# Trigger Coolify rebuild

# Option 2: Direct Container Restart
ssh root@146.196.64.92
docker restart bis_mart_backend

# Option 3: Manual Database Backup Restore
/opt/bismart/scripts/backup_postgres.sh --restore <backup-date>
```

---

## Verification Checklist

### Immediate Post-Deployment (2-3 minutes)

- [ ] Container is running
- [ ] No errors in deployment logs
- [ ] Health check returns 200
- [ ] PostgreSQL container is accessible

### Functional Testing (5-10 minutes)

- [ ] Login endpoint works
- [ ] Can create a single report
- [ ] Report data persists after reload
- [ ] Can create attendance record
- [ ] Attendance persists after reload

### Load Testing (10-15 minutes)

- [ ] Create 5+ concurrent reports via smoke test
- [ ] All reports have unique IDs (no duplicates)
- [ ] All sale items are linked to correct report
- [ ] No orphaned records in database

### Final Checks

- [ ] Production logs show no errors
- [ ] PostgreSQL backup completed successfully
- [ ] Monitoring alerts (if configured) show normal operation
- [ ] No user complaints about data loss
- [ ] Database disk usage is normal (~100MB+)

---

## Key Commands for Production VPS

```bash
# SSH to production
ssh root@146.196.64.92

# Check containers
docker ps

# View backend logs
docker logs -f bis_mart_backend

# Restart backend
docker restart bis_mart_backend

# Check PostgreSQL
docker exec bismart-postgres psql -U bismart -d bismart -c "SELECT COUNT(*) FROM sales_reports;"

# Run backup manually
/opt/bismart/scripts/backup_postgres.sh

# View recent backups
ls -lh /opt/bismart/backups/ | tail -5
```

---

## Important Notes

⚠️ **CRITICAL**: DATABASE_URL must be set in production .env
- Missing DATABASE_URL will cause app startup failure with clear error message
- No fallback to SQLite - this is intentional for data safety

✓ **ATOMIC INSERTS**: All critical operations now use RETURNING id
- Report creation: Guaranteed unique report_id per INSERT
- Attendance check-in: Guaranteed atomic check-in recording
- Sale items: Guaranteed correct report_id reference

✓ **BACKWARD COMPATIBLE**: PostgreSQL queries work with existing schema
- No schema migrations needed
- Existing data remains intact
- Old reports/attendance still accessible

✓ **IMPROVED CONCURRENCY**: Gunicorn now 2 workers × 1 thread
- Better handling of concurrent requests
- Connection pool more efficient
- Timeout set to 120 seconds for slow operations

---

## Post-Deployment Monitoring

**Recommended Metrics to Watch:**
- Response time for /api/reports: Should be <500ms
- Response time for /api/attendances/checkin: Should be <1000ms
- PostgreSQL connection pool: Monitor active connections
- Disk space: Monitor /opt/bismart/backups/ growth
- Error logs: Watch for any RETURNING id related errors

**Alert Thresholds:**
- Response time >5 seconds: Investigate
- Database errors in logs: Critical
- Backup failures: Medium priority
- CPU usage >80%: Check for N+1 queries

---

## Deployment Timeline

| Step | Duration | Status |
|------|----------|--------|
| Code merged to GitHub | Instant | ✓ Done (9ccaaab) |
| Coolify detects changes | <1 min | Pending |
| Docker rebuild | 2-3 min | Pending |
| Container startup | <30 sec | Pending |
| Health check | <10 sec | Pending |
| Smoke tests | 2-5 min | Pending |
| Production verification | 5-10 min | Pending |

**Total Expected Time**: 15-20 minutes from triggering rebuild

---

## Success Criteria

✓ **Deployment is successful when:**
1. Container starts without errors
2. /healthz returns {"status": "ok", "backend": "postgres"}
3. All 5 smoke tests pass
4. Concurrent report creation shows no duplicate IDs
5. Created reports appear in list immediately
6. No SQLite error messages in logs
7. PostgreSQL backup completed

---

**Contact & Support:**
- Bismart VPS: 146.196.64.92
- Coolify Dashboard: https://146.196.64.92 (if configured)
- GitHub Repo: https://github.com/datvu-coder/bis_mart.git
- Main Branch: Latest deployable code
