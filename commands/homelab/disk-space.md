---
allowed-tools: Bash(df:*), Bash(du:*), Bash(ncdu:*), Bash(lsblk:*), Bash(findmnt:*)
description: Analyze disk space usage across all mounts
---

## Comprehensive Disk Usage Analysis

Mount usage: !`df -h`
Large directories: !`du -h --max-depth=1 /mnt/* 2>/dev/null | sort -h | tail -20`

Perform a comprehensive disk space analysis:

1. **Mount Point Analysis**:
   - Identify filesystems above 80% usage
   - Check for critically full filesystems (>95%)
   - Note any read-only mounts that shouldn't be

2. **Space Hogs**:
   - Identify the largest directories consuming space
   - Look for unexpected large files or directories
   - Check for orphaned Docker volumes or images

3. **Growth Trends**:
   - Identify rapidly growing directories
   - Check log directories for rotation issues
   - Look for backup accumulation

4. **Cleanup Targets**:
   - Suggest safe cleanup opportunities:
     - Old log files
     - Temporary files
     - Package cache
     - Old kernels
     - Docker cleanup candidates

5. **Recommendations**:
   - Immediate actions for critical space issues
   - Long-term storage optimization suggestions
   - Monitoring setup recommendations

Provide a prioritized list of actions to reclaim disk space safely.