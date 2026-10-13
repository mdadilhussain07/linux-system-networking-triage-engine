# Linux System & Networking Production Triage Engine

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux%20Kernel%205.x%20%7C%206.x-success)](https://kernel.org)
[![Triage: USE Method](https://img.shields.io/badge/Methodology-Brendan%20Gregg%20USE-orange)](#triage-methodology)

A modular, zero-dependency incident response engine and diagnostic utility designed for rapid production triage across **CPU scheduling**, **memory exhaustion (OOM)**, **storage I/O bottlenecks**, and **TCP socket health**.

---

## Triage Methodology: The USE Matrix

The tool implements Brendan Gregg's **USE Method** (Utilization, Saturation, and Errors) across four primary Linux subsystems:

| Resource Subsystem | Metric Evaluated | Underlying Mechanism | Warning Condition |
| :--- | :--- | :--- | :--- |
| **CPU & Scheduler** | Load-to-Core Ratio | `/proc/loadavg` vs `nproc` | Ratio > 1.5 (Tasks queuing in run-queue) |
| **Memory & Swap** | Usable Memory (`MemAvailable`) | `/proc/meminfo` & `dmesg` OOM ring buffer | Usage > 90% or active OOM Killer events |
| **Storage & Disk** | Root Usage & I/O Wait (`wa`) | `df -h` & `vmstat` kernel context switching | Space > 80% or CPU I/O Wait > 15% |
| **TCP / Network** | Socket States & Interface Drops | `ss -tan` & `ip -s link` netlink queries | High `CLOSE_WAIT` (Socket leaks) or TX/RX Drops |

---

## Architectural Highlights

* **Zero External Dependencies:** Built using POSIX-compliant Bash that runs natively on any enterprise Linux distribution (Ubuntu, Debian, RHEL, Rocky Linux, Alpine) without requiring Python or third-party packages.
* **Non-Destructive Execution:** Uses read-only queries against the kernel `/proc/` pseudo-filesystem and native utilities, ensuring no diagnostic lockup during high-load production incidents.
* **Socket Inspection Performance:** Replaces legacy `/proc/net/tcp` iterators (`netstat`) with native `ss` netlink queries to prevent lock contention on high-concurrency systems.

---

## Quickstart & Usage

```bash
# Clone the triage engine
git clone [https://github.com/mdadilhussain07/linux-system-networking-triage-engine.git](https://github.com/mdadilhussain07/linux-system-networking-triage-engine.git)
cd linux-system-networking-triage-engine

# Grant execution permissions
chmod +x triage.sh

# Run immediate system diagnostic sweep
./triage.sh
