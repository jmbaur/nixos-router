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
        IgnoreCarrierLoss = true;
        MulticastDNS = true;
        Address = lib.optional (cfg.ipv6GuaPrefix != null) cfg.routerIpv6Gua.cidr;
      };
    };
  };
}
