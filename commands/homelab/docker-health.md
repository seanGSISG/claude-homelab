---
allowed-tools: Bash(docker ps:*), Bash(docker stats:*), Bash(docker inspect:*), Bash(docker logs:*), Bash(docker-compose:*)
description: Check health of all Docker containers and services
---

## Docker Container Health Check

Container Status: !`docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"`
Resource Usage: !`docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"`

Analyze the health status and identify any issues:

1. **Container States**: Check for any containers that are:
   - Exited unexpectedly
   - Restarting frequently
   - Running but unhealthy

2. **Resource Usage**: Identify containers with:
   - High CPU usage (>80%)
   - High memory usage (>90%)
   - Excessive disk usage

3. **Recent Issues**: Look for containers with recent restarts or failures

4. **Network Issues**: Check for port conflicts or network connectivity problems

5. **Recommendations**: Suggest actions for:
   - Containers that need restarting
   - Services requiring resource limit adjustments
   - Potential configuration issues

Provide a summary of the overall Docker environment health and any immediate actions required.