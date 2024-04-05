{ nixosTest, module, ... }:
let
  host1Mac = "70:ca:6e:62:ab:f6";
in
nixosTest {
  name = "router";
  nodes.router =
    { ... }:
    {
      imports = [ module ];
      virtualisation.vlans = [ 1 ];
      systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
      router = {
        enable = true;
        ipv6UlaPrefix = "fdc8:2291:4584::/64";
        wanInterface = "eth0";
        lanInterface = "eth1";
        hosts.host1.mac = host1Mac;
      };
    };

  nodes.host1 =
    { ... }:
    {
      virtualisation.vlans = [ 1 ];
      systemd.services.systemd-networkd.environment.SYSTEMD_LOG_LEVEL = "debug";
      systemd.network.networks."40-eth1".dhcpV4Config.ClientIdentifier = "mac";
      networking = {
        useNetworkd = true;
        useDHCP = false;
        firewall.enable = false;
        interfaces.eth1 = {
          useDHCP = true;
          macAddress = host1Mac;
        };
      };
    };

  testScript = builtins.readFile ./test.py;
}
