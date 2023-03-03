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
          pkgs = import inputs.nixpkgs { inherit system; };
        });
    in
    {
      nixosModules.default = { modulesPath, ... }: {
        disabledModules = [ "${modulesPath}/services/networking/avahi-daemon.nix" ];
        imports = [
          "${inputs.nixpkgs-avahi-deny-interfaces}/nixos/modules/services/networking/avahi-daemon.nix"
          ./module.nix
        ];
      };
      packages = forAllSystems ({ pkgs, ... }: {
        test = pkgs.callPackage ./test.nix { module = inputs.self.nixosModules.default; };
      });
      devShells = forAllSystems ({ pkgs, system, ... }: {
        default = pkgs.mkShell {
          inherit (inputs.pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixpkgs-fmt.enable = true;
              revive.enable = true;
              gofmt.enable = true;
            };
          }) shellHook;
          nativeBuildInputs = with pkgs; [ bashInteractive go ];
        };
      });
    };
}
