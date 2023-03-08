{ config, lib, ... }: {
  config = lib.mkIf config.router.enable {
    assertions = [{
      message = "Must not have a static host with an ID greater than or equal to 25";
      assertion = (lib.filterAttrs
        (_: network: (lib.filterAttrs (_: host: host.id >= 25) network.hosts) != { })
        config.router.inventory.networks) == { };
    }];

    systemd.network.networks = lib.mapAttrs
      (_: network: {
        name = network.physical.interface; # interface name
        linkConfig = {
          ActivationPolicy = "always-up";
        } // lib.optionalAttrs (network.mtu != null) {
          MTUBytes = toString network.mtu;
        };
        networkConfig = {
          IPv6AcceptRA = false;
          DHCPServer = true;
          IgnoreCarrierLoss = true;
          Address = [
            "${network.hosts._router._computed._ipv4Cidr}"
            "${network.hosts._router._computed._ipv6.ulaCidr}"
          ] ++ (lib.optional (config.router.v6GuaPrefix != null)
            "${network.hosts._router._computed._ipv6.guaCidr}");
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
        dhcpServerStaticLeases = lib.flatten
          (lib.mapAttrsToList
            (_: host: {
              dhcpServerStaticLeaseConfig = {
                MACAddress = host.mac;
                Address = host._computed._ipv4;
              };
            })
            (lib.filterAttrs (_: host: host.dhcp) network.hosts));
      })
      (lib.filterAttrs
        (_: network: network.physical.enable)
        config.router.inventory.networks);
  };
}
