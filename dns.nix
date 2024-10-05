{ config, lib, ... }:
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

    services.coredns = {
      enable = true;
      config = ''
        .:53 {
          bind ::
          ${lib.optionalString cfg.ipv6Only ''
            dns64 ${config.networking.jool.nat64.default.global.pool6}
          ''}
          forward . ${toString (map (ip: "tls://${ip}") dnsProvider.servers)} {
            tls_servername ${dnsProvider.serverName}
            policy random
            health_check 5s
          }
          errors
          cache 30
          prometheus :9153
        }
      '';
    };
  };
}
