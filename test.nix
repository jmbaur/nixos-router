{ nixosTest, module, ... }:
nixosTest {
  name = "router";
  nodes.router = { ... }: {
    imports = [ module ];
    router = {
      enable = true;
      v4Prefix = "192.168.0.0/16";
      v6UlaPrefix = "fc00::/48";
      wireguardEndpoint = "vpn.example.com";
      wan = "wan";
      wanSupportsDHCPv6 = true;
      heTunnelBroker.enable = false;
      inventory.networks = {
        n1 = {
          id = 1;
          physical = { enable = true; interface = "n1"; };
          hosts.h1.id = 1;
        };
        n2 = {
          id = 2;
          physical = { enable = true; interface = "n2"; };
          policy.n1.allowAll = true;
          hosts.h1.id = 1;
        };
      };
    };
  };
  testScript = builtins.readFile ./test.py;
}
