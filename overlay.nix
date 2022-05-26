self: super: {
  graylog-zabbix = self.haskellPackages.callPackage ./derivation.nix {};
}
