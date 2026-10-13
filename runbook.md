# Linux System & Networking Incident Response Runbook

This runbook outlines triage procedures for the metrics gathered by `triage.sh`.

---

## 1. High CPU Run-Queue Saturation (`Load / Core > 1.5`)

### Diagnostic Steps
1. Identify whether processes are blocked on CPU or I/O:
   ```bash
   top -b -n 1 | head -n 15
   ```
2. Check for threads stuck in uninterruptible sleep (D state):
   ```bash
   ps -eo stat,pid,user,comm | grep -E "^D"
   ```
### Remediation
1. CPU Bound (%usr / %sys high): Identify the rogue process PID. If unauthorized or stuck in a loop:
   ```bash
   kill -15 <PID>   # Graceful termination
   kill -9 <PID>    # Force kill if uncooperative
   ```
2. I/O Bound (%wa high): Check disk I/O metrics (see Section 3).


## 2. Memory Exhaustion & OOM Mitigation (Usage > 90%)

### Diagnostic Steps
1. Identify the top resident memory consumers:
   ```bash
   ps -eo pid,user,%mem,rss,comm --sort=-rss | head -n 10
   ```
(Note: RSS is Resident Set Size—actual physical RAM held by the process in KB).
2. Inspect kernel OOM killer logs:
   ```bash
   dmesg -T | grep -i "killed process"
   journalctl -k --grep="oom_killer" --since "1 hour ago"
   ```
### Remediation
1. Adjust kernel memory tunables if swapping occurs prematurely:
   ```bash
   # Check current swappiness (default is typically 60)
      cat /proc/sys/vm/swappiness
   # Lower swappiness to favor dropping page caches over swapping to disk
      sudo sysctl -w vm.swappiness=10
   ```
2. In containerized environments, inspect cgroup limits:
   ```bash
   docker stats --no-stream
   ```


## 3. Storage Latency & I/O Wait Bottlenecks (wa > 15%)

### Diagnostic Steps
1. Pinpoint which block device is saturated:
   ```bash
   iostat -xz 1 3
(Inspect %util—values over 85% indicate saturated device channels).
   ```
2. Identify the specific process issuing heavy writes:
   ```Bash
   sudo iotop -b -n 2 -o
   ```
### Remediation
1. Flush write buffers to disk to verify sync responsiveness:
   ```bash
      sync
   ```
2. Clear temporary storage if filesystem capacity triggers an alert:
   ```bash 
   sudo journalctl --vacuum-size=500M
   docker system prune -f
   ```


## 4. Socket Leaks & Port Exhaustion

### Diagnostic Steps
1. Check socket details for specific ports:
   ```bash
   ss -tulpn
   ```
2. Check socket allocation summary:
   ```bash
   ss -s
   ```
### Remediation
High CLOSE_WAIT: The local service received a FIN packet but has not executed close() on the socket.
1. Find the owning process:
   ```bash
   ss -tapn | grep CLOSE-WAIT
   ```
2. Restart the offending service to release leaked file descriptors.

High TIME_WAIT: Enable TCP socket recycling for outbound traffic:
   ```bash
   # Enable fast recycling of TIME_WAIT sockets for outgoing connections
     sudo sysctl -w net.ipv4.tcp_tw_reuse=1
   ```
---
