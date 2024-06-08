{ config, lib, ... }:
{
  imports = [
    ./dns.nix
    ./firewall.nix
    ./hostapd.nix
    ./lan.nix
    ./options.nix
    ./wan.nix
  ];

  config = lib.mkIf config.router.enable {
    networking.useDHCP = lib.mkForce false;
    systemd.network.enable = true;
  };
}
