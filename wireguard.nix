{ config, lib, pkgs, ... }:
let
  wg-config-server = pkgs.buildGoModule {
    name = "wg-config-server";
    src = ./wg-config-server;
    CGO_ENABLED = 0;
    vendorSha256 = null;
  };

  endpoint = config.router.wireguardEndpoint;
  mkWgInterface = network:
    let
      routerPrivateKeyPath = network.wireguard.privateKeyPath;
      routerPublicKey = network.wireguard.publicKey;
      port = 51800 + network.id;
    in
    {
      netdev = {
        netdevConfig = { Name = network.name; Kind = "wireguard"; };
        wireguardConfig = {
          ListenPort = port;
          PrivateKeyFile = routerPrivateKeyPath;
        };
        wireguardPeers = lib.mapAttrsToList
          (_: peer: {
            wireguardPeerConfig = {
              PublicKey = peer.publicKey;
              AllowedIPs = [
                "${peer._computed._ipv4}/32"
                "${peer._computed._ipv6.ula}/128"
              ] ++ (lib.optional (config.router.v6GuaPrefix != null)
                "${peer._computed._ipv6.gua}/128");
            };
          })
          (lib.filterAttrs (name: _: name != "_router") network.hosts);
      };
      network = {
        inherit (network) name;
        address = [
          network.hosts._router._computed._ipv4Cidr
          network.hosts._router._computed._ipv6.ulaCidr
        ] ++ (lib.optional (config.router.v6GuaPrefix != null)
          network.hosts._router._computed._ipv6.guaCidr);
      };
      clientConfigs = lib.mapAttrsToList
        (_: host:
          let
            scriptName = "wg-config-${host.name}";
            splitTunnelWgConfig = lib.generators.toINI { listsAsDuplicateKeys = true; } {
              Interface = {
                Address = [
                  host._computed._ipv4Cidr
                  host._computed._ipv6.ulaCidr
                ] ++ (lib.optional (config.router.v6GuaPrefix != null)
                  host._computed._ipv6.guaCidr);
                PrivateKey = "$(cat ${host.privateKeyPath})";
                DNS = (([ network.hosts._router._computed._ipv4 network.hosts._router._computed._ipv6.ula ])) ++ [ network.domain "home.arpa" ];
              };
              Peer = {
                PublicKey = routerPublicKey;
                Endpoint = "${endpoint}:${toString port}";
                AllowedIPs = [
                  network._computed._networkIPv4Cidr
                  network._computed._networkUlaCidr
                ]
                ++
                (lib.optional (config.router.v6GuaPrefix != null)
                  network._computed._networkGuaCidr)
                ++
                lib.flatten (
                  map
                    (name: with config.router.inventory.networks.${name};
                    ([ _computed._networkIPv4Cidr _computed._networkUlaCidr ]
                      ++ (lib.optional
                      (config.router.v6GuaPrefix != null)
                      _computed._networkGuaCidr)))
                    network.includeRoutesTo
                );
              };
            };
            fullTunnelWgConfig = lib.generators.toINI { listsAsDuplicateKeys = true; } {
              Interface = {
                Address = [
                  host._computed._ipv4Cidr
                  host._computed._ipv6.ulaCidr
                ] ++ (lib.optional (config.router.v6GuaPrefix != null)
                  host._computed._ipv6.guaCidr);
                PrivateKey = "$(cat ${host.privateKeyPath})";
                DNS = (([ network.hosts._router._computed._ipv4 network.hosts._router._computed._ipv6.ula ])) ++ [ network.domain "home.arpa" ];
              };
              Peer = {
                PublicKey = routerPublicKey;
                Endpoint = "${endpoint}:${toString port}";
                AllowedIPs = [ "0.0.0.0/0" "::/0" ];
              };
            };
          in
          pkgs.writeShellScriptBin scriptName ''
            set -eou pipefail
            case "$1" in
            text)
            printf "%s\n" "####################################################################"
            printf "%s\n" "# FULL TUNNEL"
            cat << EOF
            ${fullTunnelWgConfig}
            EOF
            printf "%s\n" "####################################################################"
            printf "%s\n" "# SPLIT TUNNEL"
            cat << EOF
            ${splitTunnelWgConfig}
            EOF
            printf "%s\n" "####################################################################"
            ;;
            qrcode)
            printf "%s\n" "####################################################################"
            printf "%s\n" "# FULL TUNNEL"
            ${pkgs.qrencode}/bin/qrencode -t ANSIUTF8 << EOF
            ${fullTunnelWgConfig}
            EOF
            printf "%s\n" "####################################################################"
            printf "%s\n" "# SPLIT TUNNEL"
            ${pkgs.qrencode}/bin/qrencode -t ANSIUTF8 << EOF
            ${splitTunnelWgConfig}
            EOF
            printf "%s\n" "####################################################################"
            ;;
            *)
            echo Usage: "$0" type-of-config
            echo   where type-of-config can be "text" or "qrcode"
            ;;
            esac
          '')
        (lib.filterAttrs (name: _: name != "_router") network.hosts);
    };

  wireguardNetworks = lib.mapAttrs
    (_: mkWgInterface)
    (lib.filterAttrs
      (_: network: network.wireguard.enable)
      config.router.inventory.networks);
in
{
  config = lib.mkIf config.router.enable {
    systemd.network.netdevs = lib.mapAttrs (_: x: x.netdev) wireguardNetworks;
    systemd.network.networks = lib.mapAttrs (_: x: x.network) wireguardNetworks;
    environment.systemPackages = [ pkgs.wireguard-tools ];
    # ++ (lib.flatten (lib.mapAttrsToList (_: x: x.clientConfigs) wireguardNetworks));

    systemd.services.wg-config-server = {
      enable = true;
      description = "wireguard config server (https://github.com/jmbaur/nixos-router/wg-config-server)";
      serviceConfig = {
        StateDirectory = "wg-config-server";
        # LoadCredential = [ "password-file:${passwordFile}" "session-secret-file:${sessionSecretFile}" ];
        ExecStart = lib.escapeShellArgs ([ "${wg-config-server}/bin/wg-config-server" ]);
        CapabilityBoundingSet = [ ];
        DeviceAllow = [ ];
        DynamicUser = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
