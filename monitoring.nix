{ config, lib, pkgs, ... }: {
  config = lib.mkIf config.router.enable {
    services.journald.enableHttpGateway = true;
    services.prometheus.exporters = {
      blackbox = {
        enable = false;
        configFile = toString ((pkgs.formats.yaml { }).generate "blackbox-config" {
          modules = {
            icmpv6_connectivity = {
              prober = "icmp";
              timeout = "5s";
              icmp = {
                preferred_ip_protocol = "ip6";
                ip_protocol_fallback = false;
              };
            };
            icmpv4_connectivity = {
              prober = "icmp";
              timeout = "5s";
              icmp = {
                preferred_ip_protocol = "ip4";
                ip_protocol_fallback = false;
              };
            };
          };
        });
      };
      node = {
        enable = true;
        enabledCollectors = [ "ethtool" "network_route" "systemd" ];
      };
    };
  };
}
