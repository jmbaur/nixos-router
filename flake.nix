{
  description = "nixos-router";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-avahi-deny-interfaces.url = "github:jmbaur/nixpkgs/avahi-daemon-deny-interfaces";
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
      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.go ];
        };
      });
    };
}
