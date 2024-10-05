{ config, lib, ... }:
let
  cfg = config.router;
in
{
  config = lib.mkIf cfg.enable {
    systemd.network.networks."10-lan" = {
      name = cfg.lanInterface;

      linkConfig = {
        # TODO(jared): the default value of "up" is probably sufficient.
        ActivationPolicy = "always-up";

        # TODO(jared): This should probably only be true for the WAN.
        RequiredForOnline = true;
      };

      networkConfig = lib.mkMerge [
        {
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

        }

        # Only setup a DHCPv4 server if we aren't using an IPv6 only LAN.
        (lib.mkIf (!cfg.ipv6Only) {
          DHCPServer = true;
          Address = "192.168.0.1/24";
        })
      ];

      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = "_link_local";
      };

      ipv6PREF64Prefixes = lib.optionals cfg.ipv6Only [
        { Prefix = config.networking.jool.nat64.default.global.pool6; }
      ];

      ipv6Prefixes =
        [
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
