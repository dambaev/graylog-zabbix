let
  pkgs = import <nixpkgs> {
    config = {};
    overlays = [
      (import ./overlay.nix)
    ];
  };
  shell = pkgs.stdenv.mkDerivation {
    name = "shell";
    buildInputs = pkgs.graylog-zabbix.nativeBuildInputs ++ [
        pkgs.haskellPackages.ghci
        pkgs.haskellPackages.ghcid
        pkgs.haskellPackages.cabal-install
      ];
  };

in shell
