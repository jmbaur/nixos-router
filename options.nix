{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.router;

  inherit (import ./lib.nix { inherit lib; })
    generateHextets
    mkUlaNetwork
    parseIpv6Network
    ;

  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  guaNetwork = parseIpv6Network cfg.ipv6GuaPrefix;
  ulaNetwork = parseIpv6Network cfg.ipv6UlaPrefix;
in
{
  options.router = {
    enable = mkEnableOption "nixos router";

    ipv6Only = mkEnableOption "IPv6-only LAN";

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
        Enable DHCPv6 on the WAN interface.
      '';
    };

    wan6PrefixHint = mkOption {
      type = types.int;
      default = 56;
      description = ''
        Prefix length that the DHVPv6 client will use to hint to the server for
        prefix delegation.
      '';
    };

    blockBogonNetworks = mkEnableOption "block bogon networks" // {
      default = true;
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

    ipv6GuaPrefix = mkOption {
      type = types.nullOr types.str;
      example = "2001:db8::1/64";
      default = null;
      description = ''
        The 64-bit IPv6 GUA network prefix (in CIDR notation).
      '';
    };

    ipv6UlaPrefix = mkOption {
      internal = true;
      readOnly = true;
      type = types.str;
      example = "fd38:5f81:b15d::/64";
      description = ''
        The 64-bit IPv6 ULA network prefix (in CIDR notation).
      '';
    };

    dns = {
      upstreamProvider = mkOption {
        type = types.enum [
          "google"
          "cloudflare"
          "quad9"
          "quad9-ecs"
        ];
        default = "google";
        description = ''
          The upstream DNS provider to use.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        # We cannot fit a host's MAC address in an IPv6 address if the network
        # is smaller than a /64.
        message = "ULA and GUA IPv6 network prefix must be greater than or equal to a /64";
        assertion =
          (cfg.ipv6GuaPrefix != null -> (guaNetwork.prefixLength <= 64)) && (ulaNetwork.prefixLength <= 64);
      }
    ];

    router.ipv6UlaPrefix = mkDefault (mkUlaNetwork (generateHextets config.networking.hostName) 64);

    environment.systemPackages = [ pkgs.conntrack-tools ];
  };
}
