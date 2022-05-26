{config, pkgs, options, lib, ...}@args:
let
  op-energy-source = ../.;
  graylog-zabbix-overlay = import ./overlay.nix;

  cfg = config.services.graylog-zabbix;
  catOrEmpty = pkgs.writeScriptBin "catOrEmpty" ''
    cat "$1" 2>/dev/null || echo ""
  '';
in
{
  options.services.graylog-zabbix.enable = lib.mkEnableOption "";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      graylog-zabbix-overlay # add graylog-zabbix
    ];
    environment.systemPackages = [ catOrEmpty ];
    services.zabbixAgent.settings = {
      UserParameter = [
        "local.graylog.sp-testnet-sstp-event-count.count,catOrEmpty /var/log/graylog-zabbix/sp-testnet-event | wc -l"
        "local.graylog.sp-testnet-sstp-event-count.last,catOrEmpty /var/log/graylog-zabbix/sp-testnet-event | tail -n 1"
      ];
    };
    services.logrotate = {
      enable = true;
      paths = {
        graylog-zabbix = {
          path = "/var/log/graylog-zabbix/*.log";
          frequency = "daily";
          keep = 14;
          priority = 1;
        };
      };
    };
    # enable graylog-zabbix service
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
      zabbix-agent = {
        path = with pkgs; [
          catOrEmpty
        ];
        serviceConfig = {
          PrivateTmp = lib.mkOverride 0 false; # we need to access some stats for UserParameter
        };
      };
    };
    users.users.zabbix-agent = {
      extraGroups = [
      ];
      isSystemUser = lib.mkOverride 0 false;
      isNormalUser = true;
    };
  };
}
