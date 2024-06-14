{ config, lib, ... }:
let
  cfg = config.router;
in
{
  config = lib.mkIf cfg.enable {
    systemd.network.networks."10-lan" = {
      name = cfg.lanInterface;
      linkConfig = {
        ActivationPolicy = "always-up";
        RequiredForOnline = true;
      };
      networkConfig = {
        DHCPPrefixDelegation = true;
        IPv6AcceptRA = false;
        IPv6SendRA = true;
        IgnoreCarrierLoss = true;
        MulticastDNS = true;
      };
      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = "_link_local";
      };
      ipv6PREF64Prefixes = [ { Prefix = config.networking.jool.nat64.default.global.pool6; } ];
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
