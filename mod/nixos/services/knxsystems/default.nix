{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.dienilles.services.knxsystems-wp =
    let
      t = lib.types;
    in
    {
      enable = lib.mkEnableOption "setup knxsystems-wp";
      hostname = lib.mkOption {
        type = t.str;
      };
      envFile = lib.mkOption {
        type = t.path;
      };
      mariaEnvFile = lib.mkOption {
        type = t.path;
      };
    };

  config =
    let
      opts = config.dienilles.services.knxsystems-wp;
    in
    lib.mkIf opts.enable {
      sops.secrets.knxsystems-wp_mariadb = {
        sopsFile = opts.mariaEnvFile;
        format = "binary";
        mode = "444";
      };

      sops.secrets.knxsystems-wp = {
        sopsFile = opts.envFile;
        format = "binary";
        mode = "444";
      };

      nix-tun.storage.persist.subvolumes."knxsystems-wp".directories = {
        "/mysql" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/wp" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
      };

      # Runtime
      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
      };
      virtualisation.oci-containers.backend = "docker";

      # Containers
      virtualisation.oci-containers.containers."knxsystems-wp-knxsystems-wp-db" = {
        image = "mysql:5.7";
        environment = {
          "MYSQL_DATABASE" = "wordpress";
          "MYSQL_RANDOM_ROOT_PASSWORD" = "1";
          "MYSQL_USER" = "wordpress";
        };
        environmentFiles = [ config.sops.secrets.knxsystems-wp_mariadb.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/knxsystems-wp/mysql:/var/lib/mysql"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=knxsystems-wp-db"
          "--network=knxsystems-wp_default"
        ];
      };
      systemd.services."docker-knxsystems-wp-knxsystems-wp-db" = {
        serviceConfig = {
          Restart = lib.mkOverride 500 "always";
          RestartMaxDelaySec = lib.mkOverride 500 "1m";
          RestartSec = lib.mkOverride 500 "100ms";
          RestartSteps = lib.mkOverride 500 9;
        };
        after = [
          "docker-network-knxsystems-wp_default.service"
          "docker-volume-knxsystems-wp_db.service"
        ];
        requires = [
          "docker-network-knxsystems-wp_default.service"
          "docker-volume-knxsystems-wp_db.service"
        ];
        partOf = [
          "docker-compose-knxsystems-wp-root.target"
        ];
        wantedBy = [
          "docker-compose-knxsystems-wp-root.target"
        ];
      };
      virtualisation.oci-containers.containers."knxsystems-wp-knxsystems-wp-website" = {
        image = "wordpress:latest";
        environment = {
          "WORDPRESS_DB_HOST" = "knxsystems-wp-db";
          "WORDPRESS_DB_NAME" = "wordpress";
          "WORDPRESS_DB_USER" = "wordpress";
        };
        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.knxsystems-wp.entrypoints" = "websecure";
          "traefik.http.routers.knxsystems-wp.rule" = "Host(`dev.knx-systems.de`)";
          "traefik.http.routers.knxsystems-wp.tls" = "true";
          "traefik.http.routers.knxsystems-wp.tls.certresolver" = "letsencrypt";
          "traefik.http.services.knxsystems-wp.loadbalancer.server.port" = "80";
          # "traefik.http.services.knxsystems-wp.loadbalancer.healthCheck.path" = "/";
        };
        environmentFiles = [ config.sops.secrets.knxsystems-wp.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/knxsystems-wp/wp:/var/www/html"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=knxsystems-wp-website"
          "--network=knxsystems-wp_default"
        ];
      };
      systemd.services."docker-knxsystems-wp-knxsystems-wp-website" = {
        serviceConfig = {
          Restart = lib.mkOverride 500 "always";
          RestartMaxDelaySec = lib.mkOverride 500 "1m";
          RestartSec = lib.mkOverride 500 "100ms";
          RestartSteps = lib.mkOverride 500 9;
        };
        after = [
          "docker-network-knxsystems-wp_default.service"
          "docker-volume-knxsystems-wp_wp.service"
        ];
        requires = [
          "docker-network-knxsystems-wp_default.service"
          "docker-volume-knxsystems-wp_wp.service"
        ];
        partOf = [
          "docker-compose-knxsystems-wp-root.target"
        ];
        wantedBy = [
          "docker-compose-knxsystems-wp-root.target"
        ];
      };

      # Networks
      systemd.services."docker-network-knxsystems-wp_default" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "docker network rm -f knxsystems-wp_default";
        };
        script = ''
          docker network inspect knxsystems-wp_default || docker network create knxsystems-wp_default
        '';
        partOf = [ "docker-compose-knxsystems-wp-root.target" ];
        wantedBy = [ "docker-compose-knxsystems-wp-root.target" ];
      };

      # Volumes
      systemd.services."docker-volume-knxsystems-wp_db" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          docker volume inspect knxsystems-wp_db || docker volume create knxsystems-wp_db
        '';
        partOf = [ "docker-compose-knxsystems-wp-root.target" ];
        wantedBy = [ "docker-compose-knxsystems-wp-root.target" ];
      };
      systemd.services."docker-volume-knxsystems-wp_wp" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          docker volume inspect knxsystems-wp_wp || docker volume create knxsystems-wp_wp
        '';
        partOf = [ "docker-compose-knxsystems-wp-root.target" ];
        wantedBy = [ "docker-compose-knxsystems-wp-root.target" ];
      };

      # Root service
      # When started, this will automatically create all resources and start
      # the containers. When stopped, this will teardown all resources.
      systemd.targets."docker-compose-knxsystems-wp-root" = {
        unitConfig = {
          Description = "Root target generated by compose2nix.";
        };
        wantedBy = [ "multi-user.target" ];
      };

    };
}
