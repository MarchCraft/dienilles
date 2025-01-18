{ lib
, config
, pkgs
, ...
}:
{
  options.dienilles.services.pterodactyl =
    let
      t = lib.types;
    in
    {
      enable = lib.mkEnableOption "setup pterodactyl";
      envFile = lib.mkOption {
        type = lib.types.path;
      };
      envFilePanel = lib.mkOption {
        type = lib.types.path;
      };
    };

  config =
    let
      opts = config.dienilles.services.pterodactyl;
    in
    lib.mkIf opts.enable {
      sops.secrets.pterodactyl = {
        sopsFile = opts.envFile;
        mode = "444";
        format = "binary";
      };
      sops.secrets.pterodactyl-panel = {
        sopsFile = opts.envFilePanel;
        mode = "444";
        format = "binary";
      };

      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
      };
      virtualisation.oci-containers.backend = "docker";

      # Containers
      virtualisation.oci-containers.containers."pterodactyl-cache" = {
        image = "redis:alpine";
        log-driver = "journald";
        extraOptions = [
          "--network-alias=cache"
          "--network=ptero0"
        ];
      };
      systemd.services."docker-pterodactyl-cache" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-ptero0.service"
        ];
        requires = [
          "docker-network-ptero0.service"
        ];
        partOf = [
          "docker-compose-pterodactyl-root.target"
        ];
        wantedBy = [
          "docker-compose-pterodactyl-root.target"
        ];
      };
      virtualisation.oci-containers.containers."pterodactyl-database" = {
        image = "mariadb:10.5";
        environment = {
          "MYSQL_DATABASE" = "panel";
          "MYSQL_USER" = "pterodactyl";
        };
        environmentFiles = [ config.sops.secrets.pterodactyl.path ];
        volumes = [
          "/opt/pterodactyl/panel/database:/var/lib/mysql:rw"
        ];
        cmd = [ "--default-authentication-plugin=mysql_native_password" ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=database"
          "--network=ptero0"
        ];
      };
      systemd.services."docker-pterodactyl-database" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-ptero0.service"
        ];
        requires = [
          "docker-network-ptero0.service"
        ];
        partOf = [
          "docker-compose-pterodactyl-root.target"
        ];
        wantedBy = [
          "docker-compose-pterodactyl-root.target"
        ];
      };
      virtualisation.oci-containers.containers."pterodactyl-panel" = {
        image = "ghcr.io/pterodactyl/panel:latest";
        environment = {
          "APP_ENV" = "production";
          "APP_ENVIRONMENT_ONLY" = "false";
          "APP_SERVICE_AUTHOR" = "felix@dienilles.de";
          "APP_TIMEZONE" = "Europe/Berlin";
          "APP_URL" = "https://minecraft.marchcraft.de";
          "CACHE_DRIVER" = "redis";
          "DB_HOST" = "database";
          "DB_PORT" = "3306";
          "QUEUE_DRIVER" = "redis";
          "REDIS_HOST" = "cache";
          "SESSION_DRIVER" = "redis";
        };
        environmentFiles = [ config.sops.secrets.pterodactyl-panel.path ];
        volumes = [
          "/opt/pterodactyl/panel/appvar/:/app/var:rw"
          "/opt/pterodactyl/panel/logs/:/app/storage/logs:rw"
          "/opt/pterodactyl/panel/nginx/:/etc/nginx/http.d:rw"
        ];
        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.minecraft.entrypoints" = "websecure";
          "traefik.http.routers.minecraft.rule" = "Host(`minecraft.marchcraft.de`)";
          "traefik.http.routers.minecraft.tls" = "true";
          "traefik.http.routers.minecraft.tls.certresolver" = "letsencrypt";
          "traefik.http.services.minecraft.loadbalancer.server.port" = "80";
        };
        log-driver = "journald";
        extraOptions = [
          "--dns=185.12.64.2"
          "--network-alias=panel"
          "--network=ptero0"
        ];
      };
      systemd.services."docker-pterodactyl-panel" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-ptero0.service"
        ];
        requires = [
          "docker-network-ptero0.service"
        ];
        partOf = [
          "docker-compose-pterodactyl-root.target"
        ];
        wantedBy = [
          "docker-compose-pterodactyl-root.target"
        ];
      };
      virtualisation.oci-containers.containers."pterodactyl-wings" = {
        image = "ghcr.io/pterodactyl/wings:latest";
        environment = {
          "TZ" = "Europe/Berlin";
          "WINGS_GID" = "0";
          "WINGS_UID" = "0";
          "WINGS_USERNAME" = "root";
        };
        volumes = [
          "/opt/pterodactyl/wings/config:/etc/pterodactyl:rw"
          "/tmp/pterodactyl/:/tmp/pterodactyl:rw"
          "/var/lib/docker/containers:/var/lib/docker/containers:rw"
          "/var/lib/pterodactyl:/var/lib/pterodactyl:rw"
          "/var/log/pterodactyl:/var/log/pterodactyl:rw"
          "/var/run/docker.sock:/var/run/docker.sock:rw"
        ];
        ports = [
          "2022:2022/tcp"
        ];
        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.minecraft-node1.entrypoints" = "websecure";
          "traefik.http.routers.minecraft-node1.rule" = "Host(`node1.marchcraft.de`)";
          "traefik.http.routers.minecraft-node1.tls" = "true";
          "traefik.http.routers.minecraft-node1.tls.certresolver" = "letsencrypt";
          "traefik.http.services.minecraft-node1.loadbalancer.server.port" = "443";
        };
        log-driver = "journald";
        extraOptions = [
          "--network-alias=wings"
          "--network=ptero0"
        ];
      };
      systemd.services."docker-pterodactyl-wings" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-ptero0.service"
        ];
        requires = [
          "docker-network-ptero0.service"
        ];
        partOf = [
          "docker-compose-pterodactyl-root.target"
        ];
        wantedBy = [
          "docker-compose-pterodactyl-root.target"
        ];
      };

      # Networks
      systemd.services."docker-network-ptero0" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "docker network rm -f ptero0";
        };
        script = ''
          docker network inspect ptero0 || docker network create ptero0 --driver=bridge --opt=com.docker.network.bridge.name=ptero0 --subnet=192.55.0.0/16
        '';
        partOf = [ "docker-compose-pterodactyl-root.target" ];
        wantedBy = [ "docker-compose-pterodactyl-root.target" ];
      };

      # Root service
      # When started, this will automatically create all resources and start
      # the containers. When stopped, this will teardown all resources.
      systemd.targets."docker-compose-pterodactyl-root" = {
        unitConfig = {
          Description = "Root target generated by compose2nix.";
        };
        wantedBy = [ "multi-user.target" ];
      };
    };
}
