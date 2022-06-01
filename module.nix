{config, pkgs, options, lib, ...}@args:
let
  op-energy-source = ../.;
  graylog-zabbix-overlay = import ./overlay.nix;

  cfg = config.services.graylog-zabbix;
  catCountOrEmpty = pkgs.writeScriptBin "catCountOrEmpty" ''
    LAST_READ_COUNT=$(catOrZero "$2")
    CURRENT_LINES_COUNT=$(catOrEmpty "$1" | wc -l)
    if [ "$CURRENT_LINES_COUNT" -lt "$LAST_READ_COUNT" ]; then
      LAST_READ_COUNT=0 # log file had been rotated, so we haven't read anything from this file yet
    fi
    UNREAD_LINES_COUNT=$(( $CURRENT_LINES_COUNT - $LAST_READ_COUNT))
    if [ "$UNREAD_LINES_COUNT" -gt 0 ]; then
      cat "$1" 2>/dev/null | tail -n $UNREAD_LINES_COUNT # we had proved, that $1 has some content by condition, send only unsent count
    else
      echo ""
    fi
    echo $CURRENT_LINES_COUNT > "$2" # store the last read count
  '';
  catOrZero = pkgs.writeScriptBin "catOrZero" ''
    cat "$1" 2>/dev/null || echo "0"
  '';
  catOrEmpty = pkgs.writeScriptBin "catOrEmpty" ''
    cat "$1" 2>/dev/null || printf ""
  '';
  grepOrEmpty = pkgs.writeScriptBin "grepOrEmpty" ''
    grep "$1" 2>/dev/null || printf ""
  '';
in
{
  options.services.graylog-zabbix.enable = lib.mkEnableOption "";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      graylog-zabbix-overlay # add graylog-zabbix
    ];
    environment.systemPackages = [ catOrEmpty grepOrEmpty catOrZero catCountOrEmpty];
    services.zabbixAgent.settings = {
      UserParameter = [
        "local.graylog.sp-testnet-sstp-event.last,catCountOrEmpty /var/log/graylog-zabbix/sp-testnet-sstp-event.log /var/log/graylog-zabbix/sp-testnet-sstp-event.last_read_count"
        "local.graylog.sp-testnet-sstp-event.count,catOrZero /var/log/graylog-zabbix/sp-testnet-sstp-event.last_read_count"
        "local.graylog.sp-testnet-sstp-event.connected.count,catOrEmpty /var/log/graylog-zabbix/sp-testnet-sstp-event.log | grepOrEmpty ' connected' | wc -l"
        "local.graylog.sp-testnet-sstp-event.disconnected.count,catOrEmpty /var/log/graylog-zabbix/sp-testnet-sstp-event.log | grepOrEmpty ' disconnected' | wc -l"
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
      zabbix-agent-init = {
        wantedBy = [ "multi-user.target" ];
        before = [ "zabbix-agent.service" ];
        serviceConfig = {
          Type = "one-shot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /var/log/graylog-zabbix
          if [ ! -e "/var/log/graylog-zabbix/sp-testnet-sstp-event.last_read_count" ]; then
            echo 0 > /var/log/graylog-zabbix/sp-testnet-sstp-event.last_read_count
          fi
          chown zabbix-agent /var/log/graylog-zabbix/sp-testnet-sstp-event.last_read_count
          chmod u+rw /var/log/graylog-zabbix/sp-testnet-sstp-event.last_read_count
        '';
      };
      zabbix-agent = {
        path = with pkgs; [
          catOrEmpty
          grepOrEmpty
          catCountOrEmpty
          catOrZero
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
