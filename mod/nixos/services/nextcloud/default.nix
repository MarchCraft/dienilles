{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
{
  options.dienilles.services.nextcloud = {
    enable = lib.mkEnableOption "nextcloud";
    hostname = lib.mkOption {
      type = lib.types.str;
    };
    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "path to the sops secret file for the nextcloud Server";
    };
  };

  config =
    let
      opts = config.dienilles.services.nextcloud;
    in
    lib.mkIf opts.enable {
      nix-tun.storage.persist.subvolumes."nextcloud".directories = {
        "/data" = {
          owner = "${builtins.toString config.containers.nextcloud.config.users.users.nextcloud.uid}";
          mode = "0700";
        };
        "/postgres" = {
          owner = "${builtins.toString config.containers.nextcloud.config.users.users.postgres.uid}";
          mode = "0700";
        };
      };

      sops.secrets.nextcloud-admin-pass = {
        sopsFile = opts.secretsFile;
        key = "admin-pass";
        mode = "444";
      };

      dienilles.services.traefik.services."nextcloud" = {
        router = {
          rule = "Host(`${opts.hostname}`)";
        };
        servers = [ "http://${config.containers.nextcloud.config.networking.hostName}:80" ];
      };

      containers.nextcloud = {
        ephemeral = true;
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.106.10";
        localAddress = "192.168.106.11";
        bindMounts = {
          "resolv" = {
            hostPath = "/etc/resolv.conf";
            mountPoint = "/etc/resolv.conf";
          };
          "data" = {
            hostPath = "${config.nix-tun.storage.persist.path}/nextcloud/data";
            mountPoint = "/var/lib/nextcloud";
            isReadOnly = false;
          };
          "admin-pass" = {
            hostPath = config.sops.secrets.nextcloud-admin-pass.path;
            mountPoint = config.sops.secrets.nextcloud-admin-pass.path;
          };
          "db" = {
            hostPath = "${config.nix-tun.storage.persist.path}/nextcloud/postgres";
            mountPoint = "/var/lib/postgresql";
            isReadOnly = false;
          };
        };

        specialArgs = {
          inherit inputs;
          host-config = config;
        };

        config = import ./container.nix;
      };
    };
}
