{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.router;

  dnsProvider = lib.getAttr cfg.dns.upstreamProvider {
    google = {
      servers = [
        "8.8.8.8"
        "8.8.4.4"
        "2001:4860:4860::8888"
        "2001:4860:4860::8844"
      ];
      serverName = "dns.google";
    };
    cloudflare = {
      servers = [
        "1.1.1.1"
        "1.0.0.1"
        "2606:4700:4700::1111"
        "2606:4700:4700::1001"
      ];
      serverName = "cloudflare-dns.com";
    };
    quad9 = {
      servers = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];
      serverName = "dns.quad9.net";
    };
    quad9-ecs = {
      servers = [
        "9.9.9.11"
        "149.112.112.11"
        "2620:fe::11"
        "2620:fe::fe:11"
      ];
      serverName = "dns11.quad9.net";
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    services.resolved = {
      enable = true;
      fallbackDns = [ ];
      extraConfig = ''
        DNS=[::1]:53
        DNSStubListener=no
      '';
    };

    services.knot-resolver = {
      enable = true;
      managerPackage = pkgs.knot-resolver-manager_6;
      package = pkgs.knot-resolver_6;
      settings = {
        network.listen = [ { interface = "::"; } ];
        dns64 = lib.mkIf cfg.ipv6Only {
          enable = true;
          prefix = config.networking.jool.nat64.default.global.pool6;
        };
        forward = [
          {
            subtree = ".";
            servers = [
              {
                address = dnsProvider.servers;
                transport = "tls";
                hostname = dnsProvider.serverName;
              }
            ];
          }
        ];
      };
    };
  };
}
