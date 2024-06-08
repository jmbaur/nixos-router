{ config, lib, ... }:
let
  heCfg = config.router.heTunnelBroker;
  wan6IsHurricaneElectric = heCfg.enable;

  devWAN = config.systemd.network.networks."10-wan".name;
  devWAN6 = if wan6IsHurricaneElectric then heCfg.name else devWAN;

  bogonNetworks = lib.mapAttrs (_: routes: map (route: route.Destination) routes) (
    builtins.partition (
      route: (builtins.match "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?" route.Destination) != null
    ) config.systemd.network.networks."10-wan".routes
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
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };

    networking.jool = {
      enable = true;
      nat64.default.global.pool6 = "64:ff9b::/96";
    };

    networking.nftables.enable = true;

    networking.firewall = {
      enable = true;
      filterForward = true;

      interfaces.${config.systemd.network.networks."10-lan".name} = {
        allowedUDPPorts = [
          53 # dns
          67 # dhcpv4
          123 # ntp
          5353 # mdns
        ];
        allowedTCPPorts = [
          53 # dns
        ];
      };

      extraInputRules = bogonInputRules;

      extraForwardRules = ''
        ${bogonInputRules}
        ${bogonOutputRules}

        iifname { ${config.systemd.network.networks."10-lan".name} } accept

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
