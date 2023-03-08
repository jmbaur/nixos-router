{ nixosTest, module, ... }:
nixosTest {
  name = "router";
  nodes.router = { ... }: {
    imports = [ module ];
    router = {
      enable = true;
      ipv4Prefix = "192.168.1.0/24";
      ipv6UlaPrefix = "fc00::/64";
      wanInterface = "wan";
      wanSupportsDHCPv6 = true;
      heTunnelBroker.enable = false;
      lanInterface = "lan";
      hosts.h1 = { id = 2; mac = "70:ca:6e:62:ab:f6"; };
    };
  };
  testScript = builtins.readFile ./test.py;
}
