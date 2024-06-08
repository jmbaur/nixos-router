{ nixosTest, module, ... }:
nixosTest {
  name = "nixos-router";

  nodes.router = {
    imports = [ module ];
    virtualisation.vlans = [ 1 ];
    router = {
      enable = true;
      ipv6UlaPrefix = "fdc8:2291:4584::/64";
      wanInterface = "eth0";
      lanInterface = "eth1";
    };
  };

  nodes.host1 =
    { lib, ... }:
    {
      virtualisation.vlans = [ 1 ];

      # don't use defaults that require internet connectivity
      services.resolved.fallbackDns = [ ];

      networking = {
        useNetworkd = true;
        useDHCP = false;
        firewall.allowedUDPPorts = [ 5353 ];
        interfaces.eth1 = lib.mkForce { };
      };

      systemd.network.enable = true;
      systemd.network.networks."10-eth1" = {
        name = "eth1";
        DHCP = "yes";
        networkConfig.MulticastDNS = true;
      };
    };

  testScript = ''
    router.wait_for_unit("network-online.target")
    host1.wait_for_unit("network-online.target")

    print(router.succeed("networkctl status eth1"))
    print(router.succeed("resolvectl"))
    print(host1.succeed("networkctl status eth1"))
    print(host1.succeed("resolvectl"))

    router.wait_until_succeeds("ping -c3 host1.local.")
    host1.wait_until_succeeds("ping -c3 router.local.")
  '';
}
