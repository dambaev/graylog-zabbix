{config, pkgs, options, lib, ...}@args:
let
  op-energy-source = ../.;
  graylog-zabbix-overlay = import ./overlay.nix;

  cfg = config.services.graylog-zabbix;
in
{
  options.services.graylog-zabbix.enable = lib.mkEnableOption "";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      graylog-zabbix-overlay # add op-energy-backend into context
    ];
    environment.systemPackages = [ ];
    # enable mysql and declare op-energy DB
    systemd.services = {
      graylog-zabbix = {
        wantedBy = [ "multi-user.target" ];
        before = [
          "graylog.service"
        ];
        requires = [
        ];
        serviceConfig = {
          Type = "simple";
        };
        path = with pkgs; [
          graylog-zabbix
        ];
        script = ''
          mkdir -p /var/log/graylog-zabbix
          graylog-zabbix +RTS -s
        '';
      };
    };
  };
}
