{ config, lib, ... }:
let
  cfg = config.router;
in
{
  config = lib.mkIf cfg.enable {
    systemd.network.networks.lan = {
      name = cfg.lanInterface;
      linkConfig = {
        ActivationPolicy = "always-up";
        RequiredForOnline = true;
      };
      networkConfig = {
        DHCPPrefixDelegation = true;
        IPv6AcceptRA = false;
        DHCPServer = true;
        IgnoreCarrierLoss = true;
        Address = [ "192.168.1.1/24" cfg.routerIpv6Ula.cidr ] ++
          lib.optional (cfg.ipv6GuaPrefix != null) cfg.routerIpv6Gua.cidr;
      };
      dhcpServerConfig = {
        EmitDNS = true;
        DNS = "_server_address";
        SendOption = [ "15:string:home.arpa" ];
      };
    };
  };
}
