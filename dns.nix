{ config, lib, pkgs, ... }:
let
  dnsProvider = lib.getAttr config.router.dns.upstreamProvider {
    google = {
      servers = [ "8.8.8.8" "8.8.4.4" "2001:4860:4860::8888" "2001:4860:4860::8844" ];
      serverName = "dns.google";
    };
    cloudflare = {
      servers = [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];
      serverName = "cloudflare-dns.com";
    };
    quad9 = {
      servers = [ "9.9.9.9" "149.112.112.112" "2620:fe::fe" "2620:fe::9" ];
      serverName = "dns.quad9.net";
    };
    quad9-ecs = {
      servers = [ "9.9.9.11" "149.112.112.11" "2620:fe::11" "2620:fe::fe:11" ];
      serverName = "dns11.quad9.net";
    };
  };

  internalDnsEntries = lib.concatMapStrings
    ({ ipv4, ipv6Ula, name, ... }: ''
      ${ipv4} ${name}.home.arpa
      ${ipv6Ula} ${name}.home.arpa
    '')
    (builtins.attrValues config.router.hosts);

  adblockHosts = pkgs.runCommand "adblock-hosts.txt" { } (''
    cat ${pkgs.stevenblack-blocklist}/hosts >$out
  '' + lib.concatMapStrings
    (category: ''
      cat ${pkgs.stevenblack-blocklist}/alternates/${category}-only/hosts >>$out
    '')
    (lib.unique config.router.dns.adblock.categories));
in
{
  config = lib.mkIf config.router.enable {
    services.resolved = {
      enable = true;
      fallbackDns = dnsProvider.servers;
    };

    # Use coredns instance for local resolution.
    networking.nameservers = [ "::1" "127.0.0.1" ];

    # Wait for IP configuration to be done on the interfaces we are binding to,
    # or else coredns will fail to start.
    systemd.services.coredns.wants = [ "network-online.target" ];
    systemd.services.coredns.after = [ "network-online.target" ];

    services.coredns = {
      enable = true;
      config = ''
        home.arpa {
          bind lo ${config.router.lanInterface}
          hosts ${pkgs.writeText "home-arpa-hosts.txt" internalDnsEntries} {
            reload 0 # the file is read-only, no need to dynamically reload it
          }
          any
          prometheus :9153
        }

        . {
          bind lo ${config.router.lanInterface}
          ${lib.optionalString config.router.dns.adblock.enable ''
            hosts ${adblockHosts} {
              reload 0 # the file is read-only, no need to dynamically reload it
              fallthrough
            }
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
