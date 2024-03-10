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

          # Automatically use the appropriate interface address as a DNS
          # server.
          rdnss = [{ }];

          # Setup IPv6-only on internal network by advertising NAT64 prefix to
          # clients.
          pref64 = [{
            prefix = config.networking.jool.nat64.default.global.pool6;
          }];
        }];
      };
    };
  };
}
