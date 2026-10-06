# **ANS-1738: Ubuntu Server LTS and AlirOS on the Platform VM**

**Owner:** James Colesanti · **Reporter:** Marty Fitzgerald · **Updated:** Oct 5, 2026

## **Summary**

Ubuntu Server 26.04 LTS (minimized) is installed on a dedicated platform VM with the components listed in ANS-1738, using chrony in place of systemd-timesyncd. The AlirOS sample stack runs on it under Docker. Running AlirOS adds six network ports that are reachable from outside the host, so the main follow-up work is in ANS-1764 (listening services) and ANS-1763 (package removal).

## **Environment**

| Item | Detail |
| :---- | :---- |
| VM | PlatformSecVM2 on Hyper-V (Generation 1), 8 GB fixed memory, separate from the dev VM |
| OS | Ubuntu Server 26.04 LTS AMD64, minimized install, kernel 7.0.0-34-generic |
| Container runtime | Docker Engine (package: docker.io) with the Compose v2 plugin |
| AlirOS stack | aliros (ghcr.io/aliro-technologies/aliro-network-stack-app:1.0.8), prometheus (prom/prometheus:v2.48.0), from sample-aliros-compose.yml Note: skip-api (aliro-skip:1.0) is omitted |
| Status | Stack starts; Prometheus loads its config; AlirOS starts with its log config. Healthcheck result: healthy |
| Evidence | Git repo with capture output tagged baseline-00, round-0b and docker-aliros; VM checkpoint and export at each milestone |

## 

## **1\. Packages included**

**Included without further explanation:** systemd, systemd-resolved, udev, iproute2, iputils-ping, procps, util-linux, bash, grep, sed, gawk, findutils, less, nano, vim, apt, dpkg. Of these, iputils-ping, less, nano, and vim were not in the minimized install and were added with \--no-install-recommends. 

**Included with a specific reason:**  
Note: rsyslog/logrotate were not in the minimized install and were added with \--no-install-recommends

| Package | Reason |
| :---- | :---- |
| chrony | Replaces systemd-timesyncd from the original list. It is the Ubuntu 26.04 default, supports authenticated time (NTS) and only listens on localhost. Approved by Marty on ANS-1738, Sep 25\. |
| sudo-rs | The sudo that actually runs on 26.04 (/usr/bin/sudo points to it). Written in Rust. |
| rust-coreutils | Provides ls, cp and the other core commands on 26.04 (uutils). Satisfies the coreutils item. |
| rsyslog, logrotate | Not in the minimized install; added so logs are written to plain files that can be forwarded. journald also runs; which one is primary is still open. |
| apparmor | Confines system services and Docker containers (docker-default profile). |
| ca-certificates | Needed for TLS to apt mirrors, GHCR, Docker Hub and NTS time servers. |
| netplan.io, systemd-networkd | Network configuration from one YAML file, without NetworkManager's desktop and Wi-Fi features. |
| Docker Engine, containerd, Compose v2 plugin | Required to run the AlirOS containers. |
| openssh-server | Remote administration; ABQNet procedures use ssh. Whether it ships is still open (ANS-1764). |
| python3 | Required by netplan.io, so it stays even after other Python packages are removed. |
| lvm2, cryptsetup | Disk layout uses LVM; cryptsetup is kept in case shipped units use full-disk encryption. |
| CPU microcode | Security fixes for the CPU on real hardware. |

## 

## 

## **Packages added manually:** iputils-ping, less, nano, vim. rsyslog, logrotate, docker-compose-v2, docker.io

## **2\. Candidates not included**

"Decided" items are settled. "Proposed" items ship with the stock install and are planned for removal in ANS-1763 after review.

| Package | Reason | Status |
| :---- | :---- | :---- |
| systemd-timesyncd | Replaced by chrony. Installing it would remove chrony. | Decided |
| docker-compose (v1) | Retired by Docker in 2023 and unmaintained. The Compose v2 plugin (docker compose) reads the same files. | Decided |
| Build and dev tooling (compilers, devcontainer, source tree, git) | AlirOS images are built on the dev VM and moved over with docker save and docker load. Building on the platform VM also ran it out of memory. | Decided |
| Audit tools (OpenSCAP, Lynis) | Run from a throwaway checkpoint or a copied script, so they never become part of the image. | Decided |
| snapd and the hwctl snap | No snaps needed. hwctl is Canonical's hardware-certification client and sends hardware details to hw.ubuntu.com. | Proposed (ANS-1763) |
| cloud-init | Not a cloud VM; only used at first boot. | Proposed (ANS-1763) |
| multipath-tools, open-iscsi, mdadm, xfsprogs, btrfs-progs, bcache-tools | Storage features not in use (no SAN, iSCSI, RAID, XFS, Btrfs or bcache). | Proposed (ANS-1763) |
| Kernel tracing tools and compiler toolchain (bpftrace, bpfcc-tools, perf, crash, binutils, C headers, kernel headers) | Installed by default. They can trace processes and build code on the box, which an attacker could use. Debugging happens on the dev VM. | Proposed (ANS-1763) |
| apport | Crash reporter that can collect and upload crash data. | Proposed (ANS-1763) |
| lxd-installer | Installs LXD and snapd on first use of lxc. AlirOS uses Docker. | Proposed (ANS-1763) |
| Classic sudo | Unused fallback next to sudo-rs; a second SUID binary. | Proposed (ANS-1763) |
| netcat-openbsd, wget, ssh-import-id, xauth, usbmuxd | No administrative need. ssh-import-id pulls SSH keys from Launchpad or GitHub; usbmuxd is for iPhones over USB. | Proposed (ANS-1763) |
| software-properties-common, packagekit, ubuntu-drivers-common | Desktop-style package and driver tools; removes polkitd and most of GnuPG with them (apt keeps gpgv). | Proposed (ANS-1763) |
| kdump-tools | A crash dump holds full memory contents, which could include key material. | Open |

## 

## **3\. What running AlirOS needed**

> * **A deployment folder, not the repo.** The repo's compose files expect a source checkout. The sample stack only needs the compose file, a config folder (log, svc, startup, logdev and metrics config, node-id.txt, prometheus.yml), a .env file and skip\_src. This matches the ABQNet layout and should become a packaged deployment bundle.  
> * **Two images.** The AlirOS app, loaded from the dev VM with docker save and docker load (pulling the app image from GHCR needs a read:packages token), and Prometheus from Docker Hub.  
> * **Docker access through sudo.** The docker group is kept empty, because membership is equivalent to root.  
> * **Bind mounts must exist before start.** A missing path is created as an empty directory and the service fails without a clear error, which is what happened on the first run.

## **4\. Starting points for follow-up work**

> * **ANS-1764, listening services:** ports 830, 8080, 8090 and 9090 (aliros), and 9999 (Prometheus) are published on all interfaces. Before AlirOS, only sshd on port 22 was reachable. The aliros container also runs its own sshd and a NETCONF server (netconfd-pro) as root; Prometheus runs as root without TLS or authentication.  
> * **ANS-1763, package removal:** the "Proposed" rows in section 2\.  
> * **Secrets:** the compose file contains an API key in plain text (api\_key for skip-api); it belongs in .env or a secrets file.  
> * **Stack scope:** the sample stack has no postgres or hw container. Confirm with Matt whether it is the full production stack and whether simulated LogDev containers apply.  
> * **Autoinstall story:** drafted, to reproduce this baseline and install the deployment bundle.  
> * **VM generation:** the VM appears to boot legacy BIOS (Gen 1): grub-pc is installed and floppy and PIIX4 modules are loaded. A Gen 2 rebuild with Secure Boot would match UEFI target hardware.

Detailed inventory, dependency groups, SUID binaries and kernel modules: [ANS-1738 Baseline Record (v3)](https://docs.google.com/document/d/1KF1nqMPVgucRJv861zBn1l7uSSqfOYj35n_VjXQacbs/edit).