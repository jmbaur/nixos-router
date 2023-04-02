{ config, lib, ... }: {
  imports = [
    ./dns.nix
    ./firewall.nix
    ./lan.nix
    ./options.nix
    ./ra.nix
    ./wan.nix
  ];

  config = lib.mkIf config.router.enable (lib.mkMerge [
    {
      services.avahi = {
        enable = false;
        openFirewall = false;
      };

      services.openntpd.enable = true;

      networking.useDHCP = lib.mkForce false;
      systemd.network.enable = true;
    }
    (lib.mkIf config.services.hostapd.enable {
      # fix hostapd startup ordering
      systemd.services.hostapd.before = [ "systemd-networkd.service" ];
    })
  ]);
}
