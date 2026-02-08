---
allowed-tools: Bash(top:*), Bash(free:*), Bash(sensors:*), Bash(uptime:*), Bash(df:*), Bash(lscpu:*), Bash(ps:*)
description: Check CPU, RAM, temps, and system load
---

## System Resource Monitoring

Load average: !`uptime`
Memory: !`free -h`
CPU usage: !`top -bn1 | head -20`
Temperatures: !`sensors 2>/dev/null || echo "lm-sensors not installed"`

Analyze the current system resource usage and identify:
1. High CPU usage processes
2. Memory pressure or potential OOM situations
3. Temperature anomalies
4. Load average trends
5. Any concerning patterns that need immediate attention

Provide recommendations for optimization if resources are constrained.