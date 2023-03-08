{ config, lib, ... }: {
  config = lib.mkIf config.router.enable {
    services.corerad = {
      enable = true;
      settings = {
        debug = { address = ":9430"; prometheus = true; };
        interfaces = (lib.optional config.router.wanSupportsDHCPv6 {
          name = config.systemd.network.networks.wan.name;
          monitor = true;
        }) ++ [{
          name = config.systemd.network.networks.lan.name;
          advertise = true;
          managed = false;
          other_config = false;
          dnssl = [{ domain_names = [ "home.arpa" ]; }];

          # Advertise all /64 prefixes on the interface.
          prefix = [{ }];

          # Automatically use the appropriate interface address as a DNS server.
          rdnss = [{ }];
        }];
      };
    };
  };
}
