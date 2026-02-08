---
allowed-tools: Bash(zpool:*), Bash(zfs:*)
description: Check ZFS pool health, scrubs, and snapshots
---

## Complete ZFS Pool Health Check

Pool status: !`zpool status -v`
Pool iostat: !`zpool iostat -v`
Dataset usage: !`zfs list -o name,used,avail,refer,mountpoint`
Recent snapshots: !`zfs list -t snapshot -o name,used,creation | head -20`

Analyze ZFS health and recommend actions:

1. **Pool Health Status**:
   - Check pool state (ONLINE, DEGRADED, FAULTED)
   - Identify any device errors or failures
   - Review checksum errors
   - Check for resilvering or scrub in progress

2. **Performance Metrics**:
   - Review read/write operations and bandwidth
   - Check for high latency
   - Identify bottlenecks
   - ARC hit ratio analysis

3. **Space Management**:
   - Dataset usage patterns
   - Compression ratios
   - Deduplication status (if enabled)
   - Available space warnings

4. **Snapshot Management**:
   - Identify old snapshots consuming space
   - Check snapshot creation schedule
   - Recommend cleanup of unnecessary snapshots
   - Verify snapshot integrity

5. **Scrub Status**:
   - Last scrub completion date
   - Errors found during last scrub
   - Recommend scrub schedule if overdue

6. **Recommendations**:
   - Immediate actions for any degraded states
   - Performance tuning suggestions
   - Space optimization opportunities
   - Backup verification reminders
   - Preventive maintenance schedule

Provide a health score summary and prioritized action items.