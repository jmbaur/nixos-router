{ config, lib, ... }:
let
  bogonNetworks = lib.filter (s: s != "") (
    lib.splitString "\n" (builtins.readFile ./bogon-networks.txt)
  );

  heCfg = config.router.heTunnelBroker;
  wan6IsHurricaneElectric = heCfg.enable;

  wan = {
    name = config.router.wanInterface;
    DHCP = if (wan6IsHurricaneElectric || !config.router.wanSupportsDHCPv6) then "ipv4" else "yes";
    networkConfig =
      {
        LinkLocalAddressing = if config.router.wanSupportsDHCPv6 then "yes" else "no";
        IPv6AcceptRA = if config.router.wanSupportsDHCPv6 then "yes" else "no";
      }
      // (lib.optionalAttrs wan6IsHurricaneElectric {
        Tunnel = config.systemd.network.netdevs."10-hurricane".netdevConfig.Name;
      });
    dhcpV4Config = {
      UseDNS = false;
      UseDomains = false;
      UseHostname = false;
      UseTimezone = false;
    };
    dhcpV6Config = lib.mkIf config.router.wanSupportsDHCPv6 {
      UseDNS = false;
      PrefixDelegationHint = "::/${toString config.router.wan6PrefixHint}";
    };
    ipv6AcceptRAConfig = {
      UseDNS = false;
      UseDomains = false;
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
  config = lib.mkIf config.router.enable {
    services.avahi.denyInterfaces = [
      config.systemd.network.networks."10-wan".name
    ] ++ (lib.optional wan6IsHurricaneElectric config.systemd.network.networks."10-hurricane".name);

    systemd.network.networks = {
      "10-wan" = wan;
      "10-hurricane" = lib.mkIf wan6IsHurricaneElectric hurricane;
    };

    systemd.network.netdevs."10-hurricane" = lib.mkIf wan6IsHurricaneElectric hurricaneNetdev;
  };
}
