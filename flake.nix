{
  description = "nixos-router";
  inputs = {
    nixpkgs-avahi-deny-interfaces.url = "github:jmbaur/nixpkgs/avahi-daemon-deny-interfaces";
    nixpkgs.url = "nixpkgs/nixos-unstable";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };
  outputs = inputs:
    let
      forAllSystems = f: inputs.nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ]
        (system: f {
          inherit system;
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };
        });
    in
    {
      overlays.default = final: prev: {
        netdump = prev.callPackage
          ({ buildGoModule, ... }: buildGoModule {
            name = "netdump";
            src = ./netdump;
            vendorSha256 = null;
          })
          { };
      };
      nixosModules.default = { modulesPath, ... }: {
        disabledModules = [ "${modulesPath}/services/networking/avahi-daemon.nix" ];
        nixpkgs.overlays = [ inputs.self.overlays.default ];
        imports = [
          "${inputs.nixpkgs-avahi-deny-interfaces}/nixos/modules/services/networking/avahi-daemon.nix"
          ./module.nix
        ];
      };
      packages = forAllSystems ({ pkgs, ... }: {
        inherit (pkgs) netdump;
        test = pkgs.callPackage ./test.nix { module = inputs.self.nixosModules.default; };
      });
      devShells = forAllSystems ({ pkgs, system, ... }: {
        default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            bashInteractive
            go
            (writeShellScriptBin "get-bogon-networks" ''
              ${curl}/bin/curl --silent https://ipgeolocation.io/resources/bogon.html |
                ${htmlq}/bin/htmlq "td:first-child" --text
            '')
          ];
          inherit (inputs.pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks.nixpkgs-fmt.enable = true;
            hooks.revive.enable = true;
            hooks.gofmt.enable = true;
          }) shellHook;
        };
      });
    };
}
