# OpenWrt LuCI eqosplus (Native fw4 Patch)

A patched, self-installing `nftables` (fw4) engine for the `eqosplus` OpenWrt LuCI app. Built specifically for OpenWrt 25.12 and newer.

## The Problem
The original `luci-app-eqosplus` package relies on outdated `tc`/`htb` queueing that breaks under modern OpenWrt `fw4`. Specifically, it:
* Fails to shape download traffic on WAN interfaces due to a NAT ingress blindspot.
* Lacks a local bypass, accidentally throttling high-speed LAN-to-LAN traffic (like reaching a local Home Assistant instance).
* Can cause network loops or CPU spikes when bound to bridge interfaces (`br-lan`).

## The Solution
This repository provides an automated installer that downloads the LuCI GUI and completely replaces the broken backend. It uses a custom, lightweight engine that translates your GUI settings directly into native `nftables` hardware policing rules.

### Features
* **True fw4 Compatibility:** Uses native `limit rate over... drop` rules instead of heavy `tc` queues, resulting in near-zero CPU usage.
* **LAN-to-LAN Bypass:** Automatically whitelists local private networks (RFC1918), ensuring internal traffic remains at gigabit speeds while only internet traffic is shaped.
* **Flexible Targeting:** Seamlessly supports single IPs (`192.168.1.50`), CIDR subnets (`192.168.1.0/24`), and arbitrary ranges (`192.168.1.10-192.168.1.50`).
* **Self-Healing:** Automatically hooks into the OpenWrt firewall to survive interface reloads (e.g., when Tailscale or WireGuard restarts).

## Installation
Run this single command via SSH on your OpenWrt router. The script dynamically detects your package manager (`apk` or `opkg`), fetches the required files, and performs the engine transplant.

```bash
wget -qO- [https://raw.githubusercontent.com/kzaoaai/openwrt-luci-eqosplus/main/install.sh](https://raw.githubusercontent.com/kzaoaai/openwrt-luci-eqosplus/main/install.sh) | sh