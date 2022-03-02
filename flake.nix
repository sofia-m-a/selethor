{
  description = "sofyr";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=master";
    flake-utils.url = "github:numtide/flake-utils";
    souffle-haskell.url = "github:smunix/souffle-haskell?ref=fix.57";
    sofialude.url = "github:sofia-m-a/sofialude";
  };
  outputs =
    inputs@{ self, nixpkgs, flake-utils, souffle-haskell, sofialude, ... }:
    flake-utils.lib.eachSystem [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ] (system:
      let
        overlays = [
          (f: _:
            with f.haskellPackages; {
              sofialude = callCabal2nix "sofialude" sofialude {
                relude = relude_1_0_0_1;
              };
            })
          souffle-haskell.overlay.${system}
        ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowBroken = true;
        };

        # https://github.com/NixOS/nixpkgs/issues/140774#issuecomment-976899227
        m1MacHsBuildTools = pkgs.haskellPackages.override {
          overrides = self: super:
            let
              workaround140774 = hpkg:
                with pkgs.haskell.lib;
                overrideCabal hpkg (drv: { enableSeparateBinOutput = false; });
            in {
              ghcid = workaround140774 super.ghcid;
              ormolu = workaround140774 super.ormolu;
            };
        };
        project = returnShellEnv:
          pkgs.haskellPackages.developPackage {
            inherit returnShellEnv;
            name = "sofyr";
            root = ./.;
            withHoogle = false;
            overrides = self: super:
              with pkgs.haskell.lib; {
                inherit (pkgs) sofialude;
              };
            modifier = drv:
              pkgs.haskell.lib.addBuildTools drv
              (with (if system == "aarch64-darwin" then
                m1MacHsBuildTools
              else
                pkgs.haskellPackages); [
                  # Specify your build/dev dependencies here.
                  cabal-fmt
                  cabal-install
                  ghcid
                  haskell-language-server
                  ormolu
                  pkgs.souffle
                  pkgs.nixpkgs-fmt
                ]);
          };
      in {
        # Used by `nix build` & `nix run` (prod exe)
        defaultPackage = project false;

        # Used by `nix develop` (dev shell)
        devShell = project true;
      });
}
