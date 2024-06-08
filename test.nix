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
    router.wait_for_unit("systemd-networkd.service")
    host1.wait_for_unit("multi-user.target")

    router.wait_until_succeeds("ping -c5 host1.local.")
    host1.wait_until_succeeds("ping -c5 router.local.")
  '';
}
