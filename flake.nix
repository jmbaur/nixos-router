{
  description = "nixos-router";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
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
      nixosModules.default = ./.;
      packages = forAllSystems ({ pkgs, ... }: {
        test = pkgs.callPackage ./test.nix { module = inputs.self.nixosModules.default; };
      });
      devShells = forAllSystems ({ pkgs, ... }: {
        netdump = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.go ];
        };
      });
    };
}
