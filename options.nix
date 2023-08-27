{ config, lib, pkgs, ... }:
let
  cfg = config.router;

  hostType = { name, config, ... }: {
    options = with lib; {
      name = mkOption {
        type = types.str;
        default = name;
        description = lib.mdDoc ''
          The name of the host. This will create a DNS entry and the host will
          be reachable at `<name>.home.arpa`.
        '';
      };
      id = mkOption {
        type = types.int;
        description = ''
          The ID of the host.
        '';
      };
      mac = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The hardware MAC address of the host.
        '';
      };
      ipv4 = mkOption { internal = true; type = types.str; };
      ipv4Cidr = mkOption { internal = true; type = types.str; };
      ipv6Ula = mkOption { internal = true; type = types.str; };
      ipv6UlaCidr = mkOption { internal = true; type = types.str; };
      ipv6Gua = mkOption { internal = true; type = types.nullOr types.str; };
      ipv6GuaCidr = mkOption { internal = true; type = types.nullOr types.str; };
    };
    config =
      let
        computed = lib.importJSON (pkgs.runCommand "hostdump-${name}.json" { } ''
          ${pkgs.pkgsBuildBuild.netdump}/bin/netdump \
            -id=${toString config.id} \
            ${lib.optionalString (config.mac != null) "-mac=${config.mac}"} \
            -ipv4-prefix=${cfg.ipv4Prefix} \
            -ipv6-ula-prefix=${cfg.ipv6UlaPrefix} \
            ${lib.optionalString (cfg.ipv6GuaPrefix != null) "-ipv6-gua-prefix=${cfg.ipv6GuaPrefix}"} \
            | tee $out
        '');
      in
      {
        inherit (computed)
          ipv4
          ipv4Cidr
          ipv6Ula
          ipv6UlaCidr
          ipv6Gua
          ipv6GuaCidr
          ;
      };
  };
in
{
  options.router = with lib; {
    enable = mkEnableOption "nixos router";
    dnsProvider = mkOption {
      type = types.enum [ "google" "cloudflare" "quad9" "quad9-ecs" ];
      default = "google";
      description = ''
        The upstream DNS provider to use.
      '';
    };
    wanInterface = mkOption {
      type = types.str;
      description = ''
        The name of the WAN interface.
      '';
    };
    wanSupportsDHCPv6 = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable dhcpv6 on the WAN interface.
      '';
    };
    wan6PrefixHint = mkOption {
      type = types.int;
      default = 56;
      description = ''
        Prefix size that the DHVPv6 client will use to hint to the server for
        prefix delegation.
      '';
    };
    heTunnelBroker = {
      enable = mkEnableOption "Hurricane Electric TunnelBroker node";
      name = mkOption {
        type = types.str;
        default = "hurricane";
        description = ''
          The name of the SIT netdev.
        '';
      };
      mtu = mkOption {
        type = types.number;
        default = 1480;
        description = ''
          The MTU of the SIT netdev.
        '';
      };
      serverIPv4Address = mkOption {
        type = types.str;
        example = "192.0.2.1";
        description = ''
          The IPv4 address of the tunnel broker server.
        '';
      };
      serverIPv6Address = mkOption {
        type = types.str;
        example = "2001:db8::1";
        description = ''
          The IPv6 address of the tunnel broker server.
        '';
      };
      clientIPv6Address = mkOption {
        type = types.str;
        example = "2001:db8::2/64";
        description = ''
          The IPv6 address of the tunnel broker client with the network's
          prefix. This option must include the network prefix.
        '';
      };
    };
    lanInterface = mkOption {
      type = types.str;
      description = ''
        The name of the physical interface that will be used for this network.
      '';
    };
    ipv4Prefix = mkOption {
      type = types.str;
      default = "192.168.1.0/24";
      description = ''
        The IPv4 network prefix (in CIDR notation).
      '';
    };
    ipv6UlaPrefix = mkOption {
      type = types.str;
      example = "fd38:5f81:b15d:0::/64";
      description = ''
        The 64-bit IPv6 ULA network prefix (in CIDR notation). One can be
        generated at https://www.ip-six.de/index.php.
      '';
    };
    ipv6GuaPrefix = mkOption {
      type = types.nullOr types.str;
      example = "2001:db8::1/64";
      default = null;
      description = ''
        The 64-bit IPv6 GUA network prefix (in CIDR notation).
      '';
    };
    hosts = mkOption {
      type = types.attrsOf (types.submodule hostType);
      default = { };
      description = ''
        The hosts in this network.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        message = "Duplicate host IDs found";
        assertion =
          let
            ids = lib.mapAttrsToList (_: host: host.id) cfg.hosts;
          in
          lib.length ids == lib.length (lib.unique ids);
      }
      {
        message = "Cannot set IPv6 GUA prefix and use DHCPv6 on the wan interface";
        assertion = (cfg.ipv6GuaPrefix != null) != cfg.wanSupportsDHCPv6;
      }
    ];

    router.hosts._router = {
      id = 1;
      name = config.networking.hostName;
    };
  };
}
