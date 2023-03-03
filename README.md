# NixOS Router

A _somewhat_ generic NixOS module for configuring a router/firewall device.

## Assumptions

This is currently a fairly opinionated nixos module, so there are some
assumptions that fit best with my current setup. I am working to make the number
of assumptions less and less.

## Requirements

- You must generate a unique local (ULA) /48 IPv6 network prefix
- You must use nftables for extra firewall configuration. The firewall built by
  this module uses nftables, so loading the iptables kernel modules will
  conflict with the nftables kernel module.
