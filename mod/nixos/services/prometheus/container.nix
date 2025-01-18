{ lib
, host-config
, pkgs
, ...
}:
let
  opts = host-config.dienilles.services.prometheus;
in
{
  networking.hostName = "prometheus";

  services.prometheus = {
    enable = true;
    globalConfig.scrape_interval = "10s";
    checkConfig = false;
    scrapeConfigs = [
      {
        job_name = "traefik";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [
              "192.168.103.10:120"
            ];
          }
        ];
      }
      {
        job_name = "node_exporter";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [
              "localhost:9100"
            ];
          }
        ];
      }
    ];
  };

  users.users.node_exporter = {
    uid = 1033;
    home = "/home/node_exporter";
    group = "users";
    shell = pkgs.bash;
    isNormalUser = true;
  };

  systemd.services.node_exporter-serve = {
    description = "Start node exporter";
    after = [ "network.target" ];
    path = [ pkgs.bash ];
    serviceConfig = {
      Type = "exec";
      User = "node_exporter";
      WorkingDirectory = "/home/node_exporter";
      ExecStart = "${pkgs.prometheus-node-exporter}/bin/node_exporter";
      Restart = "always";
      RestartSec = 5;
    };
    wantedBy = [ "multi-user.target" ];
  };

  services.grafana = {
    enable = true;
    settings = {
      database = {
        type = "postgres";
        user = "grafana";
        name = "grafana";
        host = "localhost:5432";
      };
      server = {
        http_addr = "0.0.0.0";
        http_port = 80;
        domain = "grafana.dev.dienilles.de";
      };
      "auth.generic_oauth" = {
        enabled = true;
        name = "Authentik";
        allow_sign_up = true;
        client_id = "KNnvvbVUEpxo7WQL1MGgGYRXUykaEetltIswrKRO";
        scopes = [
          "openid"
          "email"
          "profile"
          "offline_access"
          "roles"
        ];
        email_attribute_path = "email";
        login_attribute_path = "preferred_username";
        name_attribute_path = "given_name";
        auth_url = "https://auth.dev.dienilles.de/application/o/authorize/";
        token_url = "https://auth.dev.dienilles.de/application/o/token/";
        api_url = "https://auth.dev.dienilles.de/application/o/userinfo/";
        role_attribute_path = "contains(groups[*], 'admin') && 'Admin' || 'Editor'";
      };

    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [
      "grafana"
    ];
    ensureUsers = [
      {
        name = "grafana";
        ensureDBOwnership = true;
      }
    ];
    dataDir = "/var/lib/postgres";
    authentication = lib.mkOverride 10 ''
      local all       all     trust
      host  all       all     all trust
    '';
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [
        9090
        80
        9093
      ];
    };
    # Use systemd-resolved inside the container
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
  };

  system.stateVersion = "23.11";
}
