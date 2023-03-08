# NixOS Router

A NixOS module for configuring a super simple router/firewall device.

## Requirements

- You must generate a unique local (ULA) /48 IPv6 network prefix
- You must use nftables for extra firewall configuration. The firewall built by
  this module uses nftables, so loading the iptables kernel modules will
  conflict with the nftables kernel module.
