{ config, lib, ... }: {
  config = lib.mkIf config.router.enable {
    # TODO(jared): calculate DHCP pool size based on highest host ID
    assertions = [{
      message = "Must not have a static host with an ID greater than or equal to 25";
      assertion = (lib.filterAttrs (_: host: host.id >= 25) config.router.hosts) == { };
    }];

    systemd.network.networks.lan = {
      name = config.router.lanInterface;
      linkConfig.ActivationPolicy = "always-up";
      networkConfig = {
        IPv6AcceptRA = false;
        DHCPServer = true;
        IgnoreCarrierLoss = true;
        Address = [
          "${config.router.hosts._router.ipv4Cidr}"
          "${config.router.hosts._router.ipv6UlaCidr}"
        ] ++ (lib.optional (config.router.ipv6GuaPrefix != null)
          "${config.router.hosts._router.ipv6GuaCidr}");
      };
      dhcpServerConfig = {
        PoolOffset = 25;
        PoolSize = 225;
        EmitDNS = true;
        DNS = "_server_address";
        EmitNTP = true;
        NTP = "_server_address";
        SendOption = [ "15:string:home.arpa" ];
      };
      dhcpServerStaticLeases = lib.mapAttrsToList
        (_: host: {
          dhcpServerStaticLeaseConfig = {
            MACAddress = host.mac;
            Address = host.ipv4;
          };
        })
        (lib.filterAttrs (_: host: host.mac != null) config.router.hosts);
    };
  };
}
