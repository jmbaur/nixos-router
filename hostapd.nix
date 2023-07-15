# Fix for hostapd not starting before the network is configured.
{ config, lib, ... }: {
  config = lib.mkIf (config.router.enable && config.services.hostapd.enable) {
    systemd.services.hostapd.wants = [ "network-pre.target" ];
    systemd.services.hostapd.before = [ "network-pre.target" ];
  };
}
