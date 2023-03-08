{ config, lib, pkgs, ... }:
let
  mkDotDns = map (ip: "tls://${ip}");
  dnsProvider = lib.getAttr config.router.dnsProvider {
    google = {
      servers = mkDotDns [ "8.8.8.8" "8.8.4.4" "2001:4860:4860::8888" "2001:4860:4860::8844" ];
      serverName = "dns.google";
    };
    cloudflare = {
      servers = mkDotDns [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];
      serverName = "cloudflare-dns.com";
    };
    quad9 = {
      servers = mkDotDns [ "9.9.9.9" "149.112.112.112" "2620:fe::fe" "2620:fe::9" ];
      serverName = "dns.quad9.net";
    };
    quad9_ecs = {
      servers = mkDotDns [ "9.9.9.11" "149.112.112.11" "2620:fe::11" "2620:fe::fe:11" ];
      serverName = "dns11.quad9.net";
    };
  };
  internalDnsEntries = lib.concatMapStrings
    ({ ipv4, ipv6Ula, name, ... }@host: ''
      ${ipv4} ${name}.home.arpa
      ${ipv6Ula} ${name}.home.arpa
    '')
    (builtins.attrValues config.router.hosts);
in
{
  config = lib.mkIf config.router.enable {
    networking.nameservers = [ "127.0.0.1" "::1" ];
    services.resolved = {
      enable = true;
      extraConfig = ''
        DNSStubListener=no
      '';
    };

    services.coredns = {
      enable = true;
      config = ''
        home.arpa {
          hosts ${pkgs.writeText "home-arpa-hosts.txt" internalDnsEntries} {
            reload 0 # the file is read-only, no need to dynamically reload it
          }
          any
          errors
          prometheus :9153
        }

        . {
          hosts ${pkgs.stevenblack-blocklist}/hosts {
            fallthrough
          }
          forward . ${toString dnsProvider.servers} {
            tls_servername ${dnsProvider.serverName}
            policy random
            health_check 5s
          }
          cache 30
          errors {
            consolidate 5m ".* i/o timeout$" warning
            consolidate 30s "^Failed to .+"
          }
          prometheus :9153
        }
      '';
    };
  };
}
