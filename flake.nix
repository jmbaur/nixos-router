{
  description = "nixos-router";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };
  outputs =
    inputs:
    let
      forAllSystems =
        f:
        inputs.nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
        ] (system: f (import inputs.nixpkgs { inherit system; }));
    in
    {
      checks = forAllSystems (pkgs: {
        default = pkgs.callPackage ./test.nix { };
        lib = pkgs.callPackage ./lib-tests.nix { };
      });
      nixosModules.default = ./module.nix;
      formatter = forAllSystems (pkgs: pkgs.nixfmt);
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            (writeShellScriptBin "get-bogon-networks" ''
              ${curl}/bin/curl --silent --location https://ipgeolocation.io/blog/bogon-ip-addresses |
                ${htmlq}/bin/htmlq "td:first-child" --text
            '')
          ];
          inherit
            (inputs.git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
              src = ./.;
              hooks.deadnix.enable = true;
              hooks.nixfmt.enable = true;
            })
            shellHook
            ;
        };
      });
    };
}
