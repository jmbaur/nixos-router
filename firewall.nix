{ config, lib, ... }: {
  config = lib.mkIf config.router.enable {
    networking = {
      nat.enable = false;
      firewall.enable = false;
      nftables = {
        enable = true;
        ruleset = with config.systemd.network;
          let
            heCfg = config.router.heTunnelBroker;
            wan6IsHurricaneElectric = heCfg.enable;

            devWAN = networks.wan.name;
            devWAN6 = if wan6IsHurricaneElectric then heCfg.name else devWAN;

            bogonNetworks = lib.mapAttrs (_: routes: map (route: route.routeConfig.Destination) routes) (
              builtins.partition
                (route: (builtins.match
                  "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?"
                  route.routeConfig.Destination) != null
                )
                (networks.wan.routes ++
                  (lib.optionals config.router.heTunnelBroker.enable networks.hurricane.routes)
                )
            );
            v4BogonNetworks = lib.concatStringsSep ", " bogonNetworks.right;
            v6BogonNetworks = lib.concatStringsSep ", " bogonNetworks.wrong;
          in
          lib.mkForce (''
            add table inet firewall

            add chain inet firewall input { type filter hook input priority 0; policy drop; }
            add rule inet firewall input ct state vmap { established : accept, related : accept, invalid : drop }
            add rule inet firewall input iifname lo accept

            add chain inet firewall forward { type filter hook forward priority 0; policy drop; }
            add rule inet firewall forward ct state vmap { established : accept, related : accept, invalid : drop }

            add chain inet firewall output { type filter hook output priority 0; policy accept; }

            add table ip nat
            add chain ip nat prerouting { type nat hook prerouting priority 100; policy accept; }
            add chain ip nat postrouting { type nat hook postrouting priority 100; policy accept; }
            add rule ip nat postrouting ip saddr ${config.router.ipv4Prefix} oifname ${devWAN} masquerade

            # Always allow input from LAN interfaces to access crucial router IP services
            add rule inet firewall input iifname ne { ${devWAN}, ${devWAN6} } icmp type { destination-unreachable, echo-request, parameter-problem, time-exceeded } accept
            add rule inet firewall input iifname ne { ${devWAN}, ${devWAN6} } icmpv6 type { destination-unreachable, echo-request, nd-neighbor-advert, nd-neighbor-solicit, nd-router-solicit, packet-too-big, parameter-problem, time-exceeded } accept
            add rule inet firewall input iifname ne { ${devWAN}, ${devWAN6} } meta l4proto udp th dport { "bootps", "ntp" } accept
            add rule inet firewall input iifname ne { ${devWAN}, ${devWAN6} } meta l4proto { tcp, udp } th dport "domain" accept
            add rule inet firewall input iifname ne { ${devWAN}, ${devWAN6} } meta l4proto tcp th dport 8080 accept

            # Reject traffic from addresses not found on the internet
            add chain inet firewall not_in_internet
            add rule inet firewall not_in_internet iifname { ${devWAN} } ip saddr { ${v4BogonNetworks} } drop
            add rule inet firewall not_in_internet iifname { ${devWAN6} } ip6 saddr { ${v6BogonNetworks} } drop
            add rule inet firewall not_in_internet oifname { ${devWAN} } ip daddr { ${v4BogonNetworks} } drop
            add rule inet firewall not_in_internet oifname { ${devWAN6} } ip6 daddr { ${v6BogonNetworks} } drop
            add rule inet firewall input jump not_in_internet
            add rule inet firewall forward jump not_in_internet
            add rule inet firewall output jump not_in_internet

            # Allow limited icmp echo requests to wan interfaces
            add rule inet firewall input iifname . icmp type { ${devWAN} . echo-request } limit rate 5/second accept
            add rule inet firewall input iifname . icmpv6 type { ${devWAN6} . echo-request } limit rate 5/second accept

            # Allow icmpv6 echo requests to internal network hosts (needed for
            # proper IPv6 functionality)
            add rule inet firewall forward iifname . icmpv6 type { ${devWAN6} . echo-request } accept
          ''
          +
          ''

            # custom global input rules
          '' +
          (lib.concatStringsSep "\n" (lib.flatten (
            (map (port: "add rule inet firewall input meta l4proto tcp th dport ${toString port} accept") config.router.firewall.allowedTCPPorts)
              ++
              (map (port: "add rule inet firewall input meta l4proto udp th dport ${toString port} accept") config.router.firewall.allowedUDPPorts)
              ++
              (map (portRange: "add rule inet firewall input meta l4proto tcp th dport ${toString portRange.from}-${toString portRange.to} accept") config.router.firewall.allowedTCPPortRanges)
              ++
              (map (portRange: "add rule inet firewall input meta l4proto udp th dport ${toString portRange.from}-${toString portRange.to} accept") config.router.firewall.allowedUDPPortRanges)
          ))) + ''

            # custom interface-specific input rules
          '' +
          (lib.concatStringsSep "\n"
            (lib.flatten
              (lib.mapAttrsToList
                (iface: fw:
                  let
                    chain = "input_from_${iface}";
                    rangeToString = range: "${toString range.from}-${toString range.to}";
                    allowedTCPPorts = (map toString fw.allowedTCPPorts) ++ (map rangeToString fw.allowedTCPPortRanges);
                    allowedUDPPorts = (map toString fw.allowedUDPPorts) ++ (map rangeToString fw.allowedUDPPortRanges);
                  in
                  [ "add chain inet firewall ${chain}" ] ++
                    (lib.optional (allowedTCPPorts != [ ]) "add rule inet firewall ${chain} meta l4proto tcp th dport { ${lib.concatStringsSep ", " allowedTCPPorts} } accept") ++
                    (lib.optional (allowedUDPPorts != [ ]) "add rule inet firewall ${chain} meta l4proto udp th dport { ${lib.concatStringsSep ", " allowedUDPPorts} } accept") ++
                    [ "add rule inet firewall input iifname ${iface} jump ${chain}" ]
                )
                config.router.firewall.interfaces)))
          + ''

            # extra input rules
            ${lib.concatMapStringsSep "\n"
              (inputRule: "add rule inet firewall input ${inputRule}")
              (lib.filter (s: s != "") (lib.splitString "\n" config.router.firewall.extraInputRules))}
          '' + ''

            # forward rules for LAN
          '' + (
            let
              interface = config.systemd.network.networks.lan.name;
            in
            ''
              add rule inet firewall forward iifname . oifname { ${interface} . ${devWAN}, ${interface} . ${devWAN6} } accept # allow the LAN to access the internet
            ''
          )
          + ''

            # extra forward rules
            ${lib.concatMapStringsSep "\n"
              (forwardRule: "add rule inet firewall forward ${forwardRule}")
              (lib.filter (s: s != "") (lib.splitString "\n" config.router.firewall.extraForwardRules))}
          ''
          );
      };
    };
  };
}
