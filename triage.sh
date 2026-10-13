#!/usr/bin/env bash
# ==============================================================================
# Linux System & Networking Production Triage Engine
# Author: Adil Hussain (DevOps Engineering)
# Purpose: Rapid, non-destructive incident triage across CPU, Memory, Disk, & Network
# ==============================================================================

set -euo pipefail

# ANSI Color formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
}

print_alert() {
    echo -e "${RED}[ALERT] $1${NC}"
}

print_ok() {
    echo -e "${GREEN}[OK] $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

echo -e "${BOLD}======================================================================"
echo -e "   LINUX PRODUCTION INCIDENT TRIAGE ENGINE — REAL-TIME REPORT"
echo -e "   Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC') | Hostname: $(hostname)"
echo -e "   Kernel: $(uname -r) | Architecture: $(uname -m)"
echo -e "======================================================================${NC}"

# ==============================================================================
# 1. CPU & RUN-QUEUE SATURATION
# ==============================================================================
print_header "1. CPU & PROCESS SCHEDULER SATURATION"
CPU_CORES=$(nproc)
LOAD_1MIN=$(awk '{print $1}' /proc/loadavg)
LOAD_RATIO=$(awk -v l="$LOAD_1MIN" -v c="$CPU_CORES" 'BEGIN {printf "%.2f", l / c}')

echo "CPU Cores: ${CPU_CORES} | 1-Min Load Average: ${LOAD_1MIN} (Load/Core Ratio: ${LOAD_RATIO})"

if (( $(awk -v r="$LOAD_RATIO" 'BEGIN {print (r > 1.5)}') )); then
    print_alert "System CPU is oversubscribed! Tasks are queuing for execution."
elif (( $(awk -v r="$LOAD_RATIO" 'BEGIN {print (r > 1.0)}') )); then
    print_warn "CPU load is at capacity."
else
    print_ok "CPU run-queue is healthy."
fi

# Check for runaway high-CPU processes
echo -e "\nTop 3 CPU Consuming Processes:"
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 4

# ==============================================================================
# 2. MEMORY SATURATION & OOM RISK
# ==============================================================================
print_header "2. MEMORY ALLOCATION & OOM STATUS"

MEM_TOTAL=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
MEM_AVAIL=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
MEM_USED_PCT=$(awk -v t="$MEM_TOTAL" -v a="$MEM_AVAIL" 'BEGIN {printf "%.1f", ((t - a) / t) * 100}')

echo "Memory Total: $((MEM_TOTAL / 1024)) MB | Available: $((MEM_AVAIL / 1024)) MB | Usage: ${MEM_USED_PCT}%"

if (( $(awk -v u="$MEM_USED_PCT" 'BEGIN {print (u > 90.0)}') )); then
    print_alert "Critical memory pressure! High risk of kernel Out-Of-Memory (OOM) invocation."
elif (( $(awk -v u="$MEM_USED_PCT" 'BEGIN {print (u > 75.0)}') )); then
    print_warn "Memory consumption elevated."
else
    print_ok "Available memory within safe operational limits."
fi

# Check for recent kernel OOM Kills in dmesg
echo -e "\nKernel OOM Killer Invocations (Recent):"
if dmesg -T 2>/dev/null | grep -i -E "oom[-_]killer|killed process" | tail -n 3 | grep .; then
    print_alert "Kernel OOM Killer has actively terminated processes recently!"
else
    print_ok "No recent OOM kills logged in kernel ring buffer."
fi

# ==============================================================================
# 3. STORAGE I/O BOTTLENECKS
# ==============================================================================
print_header "3. STORAGE & DISK I/O SATURATION"

# Check root filesystem utilization
ROOT_DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
echo "Root (/) Partition Usage: ${ROOT_DISK_USAGE}%"

if [ "$ROOT_DISK_USAGE" -gt 90 ]; then
    print_alert "Root filesystem is nearly full! Write failures imminent."
elif [ "$ROOT_DISK_USAGE" -gt 80 ]; then
    print_warn "Root filesystem capacity exceeded 80% threshold."
else
    print_ok "Disk space capacity healthy."
fi

# Inspect I/O Wait state from vmstat (sample over 1 second)
IOWAIT=$(vmstat 1 2 | tail -1 | awk '{print $16}')
echo "CPU I/O Wait (wa): ${IOWAIT}%"
if [ "$IOWAIT" -gt 15 ]; then
    print_alert "High Disk I/O Wait detected! Storage channel is saturating CPU."
else
    print_ok "Disk I/O latency within normal bounds."
fi

# ==============================================================================
# 4. NETWORK SOCKETS & INTERFACE TRAFFIC
# ==============================================================================
print_header "4. NETWORK SOCKETS & TCP STACK METRICS"

# Count TCP states via socket statistics (ss)
ESTAB=$(ss -tan | grep -c ESTAB || true)
TIME_WAIT=$(ss -tan | grep -c TIME-WAIT || true)
CLOSE_WAIT=$(ss -tan | grep -c CLOSE-WAIT || true)
LISTEN=$(ss -tan | grep -c LISTEN || true)

echo "TCP Socket States: LISTEN=${LISTEN} | ESTABLISHED=${ESTAB} | TIME_WAIT=${TIME_WAIT} | CLOSE_WAIT=${CLOSE_WAIT}"

if [ "$CLOSE_WAIT" -gt 50 ]; then
    print_alert "High CLOSE_WAIT socket count detected! Application is leaking file descriptors by failing to close sockets."
else
    print_ok "Socket closure handling normal."
fi

# Network Interface Dropped & Error Packets
echo -e "\nNetwork Interface Packet Drops & Errors:"
ip -s link | awk '
/^[0-9]+: / {iface=$2}
/RX:/ {getline; rx_err=$3; rx_drp=$4}
/TX:/ {getline; tx_err=$3; tx_drp=$4; 
if (rx_err > 0 || rx_drp > 0 || tx_err > 0 || tx_drp > 0) 
  printf "Interface %s -> RX Errors: %s, RX Drops: %s | TX Errors: %s, TX Drops: %s\n", iface, rx_err, rx_drp, tx_err, tx_drp}
' || true

print_ok "Diagnostic sweep complete."
echo -e "${BOLD}======================================================================${NC}"
