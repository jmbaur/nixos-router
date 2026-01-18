{ testers }:
testers.nixosTest {
  name = "nixos-router";

  nodes.router = {
    imports = [ ./module.nix ];
    virtualisation.vlans = [ 1 ];
    router = {
      enable = true;
      wanInterface = "eth0";
      lanInterface = "eth1";
    };
  };

  nodes.host1 =
    { lib, ... }:
    {
      virtualisation.vlans = [ 1 ];

      # don't use defaults that require internet connectivity
      services.resolved.settings.Resolve.FallbackDns = lib.mkForce [ ];

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
    router.wait_for_unit("network.target")
    host1.wait_for_unit("network.target")

    print(router.succeed("networkctl status eth1"))
    print(router.succeed("resolvectl"))
    print(router.succeed("nft list ruleset"))
    print(host1.succeed("networkctl status eth1"))
    print(host1.succeed("resolvectl"))

    router.wait_until_succeeds("ping -c3 host1.local.")
    host1.wait_until_succeeds("ping -c3 router.local.")
  '';
}
