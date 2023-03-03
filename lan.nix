{ config, lib, ... }: {
  config = lib.mkIf config.router.enable {
    systemd.network.networks = lib.mapAttrs
      (_: network: {
        name = network.physical.interface; # interface name
        linkConfig = {
          ActivationPolicy = "always-up";
        } // lib.optionalAttrs (network.mtu != null) {
          MTUBytes = toString network.mtu;
        };
        networkConfig = {
          Address = [
            "${network.hosts._router._computed._ipv4Cidr}"
            "${network.hosts._router._computed._ipv6.ulaCidr}"
          ] ++ (lib.optional (config.router.v6GuaPrefix != null)
            "${network.hosts._router._computed._ipv6.guaCidr}");
          IPv6AcceptRA = false;
        };
      })
      (lib.filterAttrs
        (_: network: network.physical.enable)
        config.router.inventory.networks);
  };
}
