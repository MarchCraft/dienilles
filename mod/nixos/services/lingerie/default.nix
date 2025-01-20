{ lib
, config
, pkgs
, ...
}:
{
  options.dienilles.services.lingerie-wp =
    let
      t = lib.types;
    in
    {
      enable = lib.mkEnableOption "setup lingerie-wp";
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
      opts = config.dienilles.services.lingerie-wp;
    in
    lib.mkIf opts.enable {
      sops.secrets.lingerie-wp_mariadb = {
        sopsFile = opts.mariaEnvFile;
        format = "binary";
        mode = "444";
      };

      sops.secrets.lingerie-wp = {
        sopsFile = opts.envFile;
        format = "binary";
        mode = "444";
      };

      nix-tun.storage.persist.subvolumes."lingerie-wp".directories = {
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
      virtualisation.oci-containers.containers."lingerie-wp-lingerie-wp-db" = {
        image = "mysql:5.7";
        environment = {
          "MYSQL_DATABASE" = "wordpress";
          "MYSQL_RANDOM_ROOT_PASSWORD" = "1";
          "MYSQL_USER" = "wordpress";
        };
        environmentFiles = [ config.sops.secrets.lingerie-wp_mariadb.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/lingerie-wp/mysql:/var/lib/mysql"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=lingerie-wp-db"
          "--network=lingerie-wp_default"
        ];
      };
      systemd.services."docker-lingerie-wp-lingerie-wp-db" = {
        serviceConfig = {
          Restart = lib.mkOverride 500 "always";
          RestartMaxDelaySec = lib.mkOverride 500 "1m";
          RestartSec = lib.mkOverride 500 "100ms";
          RestartSteps = lib.mkOverride 500 9;
        };
        after = [
          "docker-network-lingerie-wp_default.service"
          "docker-volume-lingerie-wp_db.service"
        ];
        requires = [
          "docker-network-lingerie-wp_default.service"
          "docker-volume-lingerie-wp_db.service"
        ];
        partOf = [
          "docker-compose-lingerie-wp-root.target"
        ];
        wantedBy = [
          "docker-compose-lingerie-wp-root.target"
        ];
      };
      virtualisation.oci-containers.containers."lingerie-wp-lingerie-wp-website" = {
        image = "wordpress:latest";
        environment = {
          "WORDPRESS_DB_HOST" = "lingerie-wp-db";
          "WORDPRESS_DB_NAME" = "wordpress";
          "WORDPRESS_DB_USER" = "wordpress";
        };
        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.lingerie-wp.entrypoints" = "websecure";
          "traefik.http.routers.lingerie-wp.rule" = "Host(`lingerie-nilles.de`)";
          "traefik.http.routers.lingerie-wp.tls" = "true";
          "traefik.http.routers.lingerie-wp.tls.certresolver" = "letsencrypt";
          "traefik.http.services.lingerie-wp.loadbalancer.server.port" = "80";
          # "traefik.http.services.lingerie-wp.loadbalancer.healthCheck.path" = "/";
        };
        environmentFiles = [ config.sops.secrets.lingerie-wp.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/lingerie-wp/wp:/var/www/html"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=lingerie-wp-website"
          "--network=lingerie-wp_default"
        ];
      };
      systemd.services."docker-lingerie-wp-lingerie-wp-website" = {
        serviceConfig = {
          Restart = lib.mkOverride 500 "always";
          RestartMaxDelaySec = lib.mkOverride 500 "1m";
          RestartSec = lib.mkOverride 500 "100ms";
          RestartSteps = lib.mkOverride 500 9;
        };
        after = [
          "docker-network-lingerie-wp_default.service"
          "docker-volume-lingerie-wp_wp.service"
        ];
        requires = [
          "docker-network-lingerie-wp_default.service"
          "docker-volume-lingerie-wp_wp.service"
        ];
        partOf = [
          "docker-compose-lingerie-wp-root.target"
        ];
        wantedBy = [
          "docker-compose-lingerie-wp-root.target"
        ];
      };

      # Networks
      systemd.services."docker-network-lingerie-wp_default" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "docker network rm -f lingerie-wp_default";
        };
        script = ''
          docker network inspect lingerie-wp_default || docker network create lingerie-wp_default
        '';
        partOf = [ "docker-compose-lingerie-wp-root.target" ];
        wantedBy = [ "docker-compose-lingerie-wp-root.target" ];
      };

      # Volumes
      systemd.services."docker-volume-lingerie-wp_db" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          docker volume inspect lingerie-wp_db || docker volume create lingerie-wp_db
        '';
        partOf = [ "docker-compose-lingerie-wp-root.target" ];
        wantedBy = [ "docker-compose-lingerie-wp-root.target" ];
      };
      systemd.services."docker-volume-lingerie-wp_wp" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          docker volume inspect lingerie-wp_wp || docker volume create lingerie-wp_wp
        '';
        partOf = [ "docker-compose-lingerie-wp-root.target" ];
        wantedBy = [ "docker-compose-lingerie-wp-root.target" ];
      };

      # Root service
      # When started, this will automatically create all resources and start
      # the containers. When stopped, this will teardown all resources.
      systemd.targets."docker-compose-lingerie-wp-root" = {
        unitConfig = {
          Description = "Root target generated by compose2nix.";
        };
        wantedBy = [ "multi-user.target" ];
      };

    };
}
