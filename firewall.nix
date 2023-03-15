{ config, lib, ... }:
let
  heCfg = config.router.heTunnelBroker;
  wan6IsHurricaneElectric = heCfg.enable;

  devWAN = config.systemd.network.networks.wan.name;
  devWAN6 = if wan6IsHurricaneElectric then heCfg.name else devWAN;

  bogonNetworks = lib.mapAttrs (_: routes: map (route: route.routeConfig.Destination) routes) (
    builtins.partition
      (route: (builtins.match
        "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?"
        route.routeConfig.Destination) != null
      )
      config.systemd.network.networks.wan.routes
  );
  v4BogonNetworks = lib.concatStringsSep ", " bogonNetworks.right;
  v6BogonNetworks = lib.concatStringsSep ", " bogonNetworks.wrong;
  bogonInputRules = ''
    iifname { ${devWAN} } ip saddr { ${v4BogonNetworks} } drop
    iifname { ${devWAN6} } ip6 saddr { ${v6BogonNetworks} } drop
  '';
  bogonOutputRules = ''
    oifname { ${devWAN} } ip daddr { ${v4BogonNetworks} } drop
    oifname { ${devWAN6} } ip6 daddr { ${v6BogonNetworks} } drop
  '';
in
{
  config = lib.mkIf config.router.enable {
    networking.nat = {
      enable = true;
      externalInterface = devWAN;
      internalInterfaces = [ config.systemd.network.networks.lan.name ];
    };

    networking.nftables.enable = true;

    networking.firewall = {
      enable = true;
      pingLimit = "5/second";
      filterForward = true;

      interfaces.${config.systemd.network.networks.lan.name} = {
        allowedUDPPorts = [
          53 # dns
          67 # dhcpv4
          123 # ntp
        ];
        allowedTCPPorts = [
          53 # dns
        ];
      };

      extraInputRules = ''
        ${bogonInputRules}

        iifname ne { ${devWAN}, ${devWAN6} } icmp type { destination-unreachable, echo-request, parameter-problem, time-exceeded } accept
        iifname ne { ${devWAN}, ${devWAN6} } icmpv6 type { destination-unreachable, echo-request, nd-neighbor-advert, nd-neighbor-solicit, nd-router-solicit, packet-too-big, parameter-problem, time-exceeded } accept
      '';

      extraForwardRules = ''
        ${bogonInputRules}
        ${bogonOutputRules}

        # Allow icmpv6 echo requests to internal network hosts (needed for
        # proper IPv6 functionality)
        iifname . icmpv6 type { ${devWAN6} . echo-request } accept

        ${lib.optionalString wan6IsHurricaneElectric ''
          # The nixpkgs NAT module sets up forward rules for one external
          # interface. Make sure it is setup here for a hurricane electric
          # tunnel interface.
          iifname { ${lib.concatStringsSep ", " config.networking.nat.internalInterfaces} } oifname ${devWAN6} accept
        ''}
      '';
    };
  };
}
