{ config, lib, ... }:
let
  inherit (lib)
    filter
    mkIf
    mkMerge
    optionals
    splitString
    ;

  bogonNetworks = filter (s: s != "") (splitString "\n" (builtins.readFile ./bogon-networks.txt));

  heCfg = config.router.heTunnelBroker;
  wan6IsHurricaneElectric = heCfg.enable;

  commonDHCP = {
    UseDNS = false;
    UseHostname = false;
  };

  wan = {
    name = config.router.wanInterface;
    DHCP = if wan6IsHurricaneElectric || !config.router.wanSupportsDHCPv6 then "ipv4" else "yes";
    networkConfig = mkMerge [
      {
        LinkLocalAddressing = if config.router.wanSupportsDHCPv6 then "yes" else "no";
        IPv6AcceptRA = if config.router.wanSupportsDHCPv6 then "yes" else "no";

        # We use our own DNS config in this module, no need to accept search
        # domain from ISP. This causes UseDomains=no to be set for all client
        # protocols (DHCPv4, DHCPv6, IPv6RA, etc).
        UseDomains = false;
      }
      (mkIf wan6IsHurricaneElectric {
        Tunnel = config.systemd.network.netdevs."10-hurricane".netdevConfig.Name;
      })
    ];
    dhcpV4Config = mkMerge [
      commonDHCP
      (mkIf (config.time.timeZone != null) { useTimezone = false; })
    ];
    dhcpV6Config = (
      mkIf config.router.wanSupportsDHCPv6 (mkMerge [
        commonDHCP
        {
          PrefixDelegationHint = "::/${toString config.router.wan6PrefixHint}";
        }
      ])
    );
    ipv6AcceptRAConfig = {
      UseDNS = false;
    };
    linkConfig = {
      RequiredForOnline = true;
      RequiredFamilyForOnline =
        if (wan6IsHurricaneElectric || !config.router.wanSupportsDHCPv6) then "ipv4" else "any";
    };
    routes = map (Destination: {
      inherit Destination;
      Type = "unreachable";
    }) bogonNetworks;
  };

  hurricane = {
    inherit (heCfg) name;
    networkConfig = {
      Address = heCfg.clientIPv6Address;
      Gateway = heCfg.serverIPv6Address;
    };
    linkConfig.RequiredFamilyForOnline = "ipv6";
    routes = map (Destination: {
      inherit Destination;
      Type = "unreachable";
    }) bogonNetworks;
  };

  hurricaneNetdev = {
    tunnelConfig.Remote = heCfg.serverIPv4Address;
    netdevConfig = {
      Name = heCfg.name;
      Kind = "sit";
      MTUBytes = toString heCfg.mtu;
    };
    tunnelConfig = {
      Local = "any";
      TTL = 255;
    };
  };
in
{
  config = mkIf config.router.enable {
    services.avahi.denyInterfaces =
      [
        config.systemd.network.networks."10-wan".name
      ]
      ++ optionals wan6IsHurricaneElectric [
        config.systemd.network.networks."10-hurricane".name
      ];

    systemd.network.networks = {
      "10-wan" = wan;
      "10-hurricane" = mkIf wan6IsHurricaneElectric hurricane;
    };

    systemd.network.netdevs."10-hurricane" = mkIf wan6IsHurricaneElectric hurricaneNetdev;
  };
}
