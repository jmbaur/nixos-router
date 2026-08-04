{ config, lib, ... }:
let
  cfg = config.router;
in
{
  config = lib.mkIf cfg.enable {
    systemd.network.networks."10-lan" = {
      name = cfg.lanInterface;

      # LAN link not required for the machine to be considered "online".
      linkConfig.RequiredForOnline = false;

      networkConfig = {
        # Delegate prefixes found from DHCPv6 clients on other links.
        DHCPPrefixDelegation = true;

        # We are a router, we don't accept router advertisements on this link.
        IPv6AcceptRA = false;

        # Advertise that we are a router on the link to clients on the LAN.
        IPv6SendRA = true;

        # Allow mDNS to work on the LAN.
        MulticastDNS = true;

        # We want the LAN interface to be configured regardless of carrier
        # state.
        ConfigureWithoutCarrier = true;

        # Setup a DHCPv4 server, DHCP option 108 is set below when using an
        # IPv6 mostly setup.
        DHCPServer = true;
        IPMasquerade = "ipv4";
        Address = "192.168.0.1/24";
      };

      dhcpServerConfig = {
        EmitDNS = true;
        DNS = "_server_address";
        IPv6OnlyPreferredSec = lib.mkIf cfg.ipv6Mostly "1d";
      };

      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = "_link_local";
      };

      ipv6PREF64Prefixes = lib.optionals cfg.ipv6Mostly [
        { Prefix = config.networking.jool.nat64.default.global.pool6; }
      ];

      ipv6Prefixes = [
        {
          Prefix = cfg.ipv6UlaPrefix;
          Assign = true;
        }
      ]
      ++ lib.optionals (cfg.ipv6GuaPrefix != null) [
        {
          Prefix = cfg.ipv6GuaPrefix;
          Assign = true;
        }
      ];
    };
  };
}
