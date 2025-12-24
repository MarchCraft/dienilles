{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
{
  options.dienilles.services.vaultwarden = {
    enable = lib.mkEnableOption "setup vaultwarden";
    secretsFile = lib.mkOption {
      type = lib.types.path;
      description = "path to the sops secret file for the vaultwarden website Server";
    };
    hostname = lib.mkOption {
      type = lib.types.str;
    };
  };

  config =
    let
      opts = config.dienilles.services.vaultwarden;
    in
    lib.mkIf opts.enable {
      sops.secrets.vaultwarden = {
        sopsFile = opts.secretsFile;
        format = "binary";
        mode = "444";
      };

      nix-tun.storage.persist.subvolumes."vaultwarden".directories = {
        "/db" = {
          owner = "${builtins.toString config.containers.vaultwarden.config.users.users.vaultwarden.uid}";
          mode = "0700";
        };
      };

      dienilles.services.traefik.services."vaultwarden" = {
        router = {
          rule = "Host(`${opts.hostname}`)";
        };
        healthCheck = {
          enable = true;
        };
        servers = [ "http://${config.containers.vaultwarden.localAddress}:8222" ];
      };

      dienilles.services.traefik.services."vaultwarden_fix" = {
        router = {
          rule = "Host(`${opts.hostname}`) && Path(`/api/tasks`)";
        };
        servers = [ "http://${config.containers.vaultwarden.localAddress}" ];
      };

      containers.vaultwarden = {
        ephemeral = true;
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.104.10";
        localAddress = "192.168.104.11";
        bindMounts = {
          "resolv" = {
            hostPath = "/etc/resolv.conf";
            mountPoint = "/etc/resolv.conf";
          };
          "secret" = {
            hostPath = config.sops.secrets.vaultwarden.path;
            mountPoint = config.sops.secrets.vaultwarden.path;
          };
          "db" = {
            hostPath = "${config.nix-tun.storage.persist.path}/vaultwarden/db";
            mountPoint = "/var/lib/bitwarden_rs";
            isReadOnly = false;
          };
        };

        specialArgs = {
          inherit inputs pkgs;
          host-config = config;
        };

        config = import ./container.nix;
      };
    };
}
