{
  description = "nixos-router";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };
  outputs = inputs:
    let
      forAllSystems = f: inputs.nixpkgs.lib.genAttrs
        [ "x86_64-linux" "aarch64-linux" ]
        (system: f (import inputs.nixpkgs { inherit system; }));
    in
    {
      checks = forAllSystems (pkgs: {
        # default = pkgs.callPackage ./test.nix { };
        lib = pkgs.callPackage ./lib-tests.nix { };
      });
      nixosModules.default = ./module.nix;
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            (writeShellScriptBin "get-bogon-networks" ''
              ${curl}/bin/curl --silent https://ipgeolocation.io/resources/bogon.html |
                ${htmlq}/bin/htmlq "td:first-child" --text
            '')
          ];
          inherit (inputs.pre-commit-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
            src = ./.;
            hooks.deadnix.enable = true;
            hooks.nixpkgs-fmt.enable = true;
          }) shellHook;
        };
      });
    };
}
