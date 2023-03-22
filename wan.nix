{ config, lib, ... }:
let
  bogonNetworks = lib.filter (s: s != "") (lib.splitString "\n" (builtins.readFile ./bogon-networks.txt));

  heCfg = config.router.heTunnelBroker;
  wan6IsHurricaneElectric = heCfg.enable;

  wan = {
    name = config.router.wanInterface;
    DHCP = if (wan6IsHurricaneElectric || !config.router.wanSupportsDHCPv6) then "ipv4" else "yes";
    networkConfig = {
      LinkLocalAddressing = config.router.wanSupportsDHCPv6;
      IPv6AcceptRA = config.router.wanSupportsDHCPv6;
      IPForward = true;
    } // (lib.optionalAttrs wan6IsHurricaneElectric {
      Tunnel = config.systemd.network.netdevs.hurricane.netdevConfig.Name;
    });
    dhcpV4Config = {
      UseDNS = false;
      UseDomains = false;
      UseHostname = false;
      UseTimezone = false;
    };
    dhcpV6Config = lib.mkIf config.router.wanSupportsDHCPv6 {
      UseDNS = false;
      UseDomains = false;
      UseHostname = false;
      UseTimezone = false;
      PrefixDelegationHint = "::/${toString config.router.wan6PrefixHint}";
    };
    linkConfig.RequiredFamilyForOnline = if (wan6IsHurricaneElectric || !config.router.wanSupportsDHCPv6) then "ipv4" else "any";
    routes = map
      (Destination: {
        routeConfig = { inherit Destination; Type = "unreachable"; };
      })
      bogonNetworks;
  };


  hurricane = {
    inherit (heCfg) name;
    networkConfig = {
      Address = heCfg.clientIPv6Address;
      Gateway = heCfg.serverIPv6Address;
    };
    linkConfig.RequiredFamilyForOnline = "ipv6";
    routes = map
      (Destination: {
        routeConfig = { inherit Destination; Type = "unreachable"; };
      })
      bogonNetworks;
  };

  hurricaneNetdev = {
    tunnelConfig.Remote = heCfg.serverIPv4Address;
    netdevConfig = {
      Name = heCfg.name;
      Kind = "sit";
      MTUBytes = toString heCfg.mtu;
    };
    tunnelConfig = { Local = "any"; TTL = 255; };
  };
in
{
  config = lib.mkIf config.router.enable {
    services.avahi.denyInterfaces = [ config.systemd.network.networks.wan.name ]
      ++ (lib.optional
      wan6IsHurricaneElectric
      config.systemd.network.networks.hurricane.name);

    systemd.network.networks = { inherit wan; } //
      lib.optionalAttrs wan6IsHurricaneElectric { inherit hurricane; };

    systemd.network.netdevs = lib.mkIf wan6IsHurricaneElectric {
      hurricane = hurricaneNetdev;
    };
  };
}
