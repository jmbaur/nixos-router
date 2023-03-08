{ config, lib, pkgs, ... }: {
  imports = [
    ./dns.nix
    ./firewall.nix
    ./lan.nix
    ./monitoring.nix
    ./options.nix
    ./ra.nix
    ./wan.nix
    ./wireguard.nix
  ];

  config = lib.mkIf config.router.enable {
    services.avahi = {
      enable = false;
      openFirewall = false;
    };

    services.ntp = {
      enable = true;
      # continue to serve time to the network in case internet access is lost
      extraConfig = ''
        tos orphan 15
      '';
    };

    networking.useDHCP = lib.mkForce false;
    systemd.network.enable = true;

    environment.etc."inventory.json".source = (pkgs.formats.json { }).generate
      "inventory.json"
      config.router.inventory;
  };
}
