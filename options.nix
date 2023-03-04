{ options, config, lib, pkgs, ... }:
let
  cfg = config.router;

  routerHostName = config.networking.hostName;

  hostType = { name, config, networkConfig, ... }: {
    options = with lib; {
      id = mkOption { type = types.int; };
      name = mkOption { type = types.str; default = name; };
      dhcp = mkEnableOption "dhcp-enabled host";
      mac = mkOption { type = types.nullOr types.str; default = null; };
      publicKey = mkOption { type = types.nullOr types.str; default = null; };
      privateKeyPath = mkOption { type = types.nullOr types.path; default = null; };
      _computed = {
        _ipv4 = mkOption { internal = true; type = types.str; };
        _ipv4Cidr = mkOption { internal = true; type = types.str; };
        _ipv6.ula = mkOption { internal = true; type = types.str; };
        _ipv6.ulaCidr = mkOption { internal = true; type = types.str; };
        _ipv6.gua = mkOption { internal = true; type = types.nullOr types.str; };
        _ipv6.guaCidr = mkOption { internal = true; type = types.nullOr types.str; };
      };
    };
    config = {
      _computed = lib.importJSON (pkgs.runCommand "hostdump-${name}.json" { } ''
        ${pkgs.pkgsBuildBuild.netdump}/bin/netdump \
          -host \
          -id=${toString config.id} \
          -v4-prefix=${networkConfig._computed._v4Prefix} \
          -ula-prefix=${networkConfig._computed._v6UlaPrefix} \
          ${lib.optionalString (networkConfig._computed._v6GuaPrefix != null) "-gua-prefix=${networkConfig._computed._v6GuaPrefix}"} \
          | tee $out
      '');
    };
  };

  policyType = { name, config, ... }: {
    options = with lib; {
      name = mkOption {
        type = types.str;
        default = name;
        description = ''
          The name of the network this policy will apply to. If the name of the
          network is "default", the policy will apply globally.
        '';
      };
      allowAll = mkEnableOption "allow all traffic";
      includeRouteTo = mkOption {
        type = types.bool;
        default = config.allowAll;
        description = ''
          Whether to advertise a route for the network owning this policy to
          the network described in this policy.
        '';
      };
      allowedTCPPorts = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = ''
          Allowed TCP ports. This is overridden by `allowAll`.
        '';
      };
      allowedUDPPorts = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = ''
          Allowed UDP ports. This is overridden by `allowAll`.
        '';
      };
    };
  };

  networkType = { name, config, ... }: {
    options = with lib; {
      name = mkOption {
        type = types.str;
        default = name;
        description = ''
          The name of the network.
        '';
      };
      id = mkOption { type = types.int; };
      physical = {
        enable = mkEnableOption "physical network";
        interface = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            The name of the physical interface that will be used for this network.
          '';
        };
      };
      wireguard = {
        enable = mkEnableOption "wireguard network";
        privateKeyPath = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            The path to the private key of the router for this network.
          '';
        };
        publicKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            The wireguard public key of the router for this network.
          '';
        };
      };
      domain = mkOption {
        type = types.str;
        default = "${config.name}.home.arpa";
        description = ''
          The domain name of the network.
        '';
      };
      hosts = mkOption {
        type = types.attrsOf (types.submoduleWith {
          modules = [ hostType ];
          specialArgs.networkConfig = config;
        });
        default = { };
        description = ''
          The hosts that belong in this network.
        '';
      };
      policy = mkOption {
        type = types.attrsOf (types.submodule policyType);
        default = { };
        description = ''
          The firewall policy of this network.
        '';
      };
      includeRoutesTo = mkOption {
        internal = true;
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Names of other networks that this network should have routes
          configured for. Routes to these networks will be handed out via
          DHCPv4 and IPv6 RA.
        '';
      };
      mtu = mkOption { type = types.nullOr types.int; default = null; };
      _computed = {
        _ipv4Cidr = mkOption { internal = true; type = types.int; };
        _ipv6UlaCidr = mkOption { internal = true; type = types.int; };
        _ipv6GuaCidr = mkOption { internal = true; type = types.nullOr types.int; };
        _networkIPv4 = mkOption { internal = true; type = types.str; };
        _networkIPv4Cidr = mkOption { internal = true; type = types.str; };
        _networkIPv4SignificantOctets = mkOption { internal = true; type = types.str; };
        _dhcpv4Pool = mkOption { internal = true; type = types.str; };
        _networkUlaCidr = mkOption { internal = true; type = types.str; };
        _networkGuaCidr = mkOption { internal = true; type = types.nullOr types.str; };
        _dhcpv6Pool = mkOption { internal = true; type = types.str; };
        _v4Prefix = mkOption { internal = true; type = types.str; default = config._computed._networkIPv4Cidr; };
        _v6UlaPrefix = mkOption { internal = true; type = types.str; default = config._computed._networkUlaCidr; };
        _v6GuaPrefix = mkOption { internal = true; type = types.nullOr types.str; default = config._computed._networkGuaCidr; };
      };
    };

    config = {
      _computed = lib.importJSON (pkgs.runCommand "netdump-${name}.json" { } ''
        ${pkgs.pkgsBuildBuild.netdump}/bin/netdump \
          -network \
          -id=${toString config.id} \
          -v4-prefix=${cfg.v4Prefix} \
          -ula-prefix=${cfg.v6UlaPrefix} \
          ${lib.optionalString (cfg.v6GuaPrefix != null) "-gua-prefix=${cfg.v6GuaPrefix}"} \
          | tee $out
      '');
      hosts._router = { id = 1; name = routerHostName; };
      includeRoutesTo = map
        (network: network.name)
        (lib.filter
          (network: (
            (config.name != network.name)
            && (lib.attrByPath [ config.name "includeRouteTo" ] false network.policy)
          ))
          (builtins.attrValues cfg.inventory.networks));
    };
  };

in
{
  options.router = with lib; {
    enable = mkEnableOption "nixos router";
    upstreamDnsProvider = mkOption {
      type = types.enum [ "google" "cloudflare" "quad9" "quad9_ecs" ];
      default = "quad9_ecs";
    };
    v4Prefix = mkOption { type = types.str; };
    v6GuaPrefix = mkOption { type = types.nullOr types.str; default = null; };
    v6UlaPrefix = mkOption { type = types.str; };
    wireguardEndpoint = mkOption { type = types.str; };
    wan = mkOption {
      type = types.str;
      description = ''
        The name of the WAN interface.
      '';
    };
    wanSupportsDHCPv6 = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable dhcpv6 on the wan interface.
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
        example = "2001:DB8::1";
        description = ''
          The IPv6 address of the tunnel broker server.
        '';
      };
      clientIPv6Address = mkOption {
        type = types.str;
        example = "2001:DB8::2/64";
        description = ''
          The IPv6 address of the tunnel broker client with the network's
          prefix. This option must include the network prefix.
        '';
      };
    };
    # duplicate `networking.firewall` options that are implemented in nftables in
    # this module.
    firewall = {
      inherit (options.networking.firewall) interfaces;
    };
    inventory = {
      networks = mkOption {
        type = types.attrsOf (types.submodule networkType);
        default = { };
        description = ''
          The networks to be configured by the router.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        message = "Cannot have physical.enable and wireguard.enable set for the same network";
        assertion = (lib.filterAttrs
          (_: network: network.physical.enable && network.wireguard.enable)
          cfg.inventory.networks) == { };
      }
      (
        let
          ips = lib.flatten
            (map (network:
              (map
                (host:
                  with host._computed; [ _ipv4 _ipv6.gua _ipv6.ula ])
                (builtins.attrValues network.hosts))
                (builtins.attrValues cfg.inventory.networks)));
        in
        {
          assertion = lib.length ips == lib.length (lib.unique ips);
          message = "Duplicate IP addresses found";
        }
      )
      {
        assertion = ((cfg.v6GuaPrefix != null) != cfg.wanSupportsDHCPv6);
        message = "Cannot set IPv6 GUA prefix and use DHCPv6 on the wan interface";
      }
    ];
  };
}
