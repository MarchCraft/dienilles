{ lib
, config
, inputs
, pkgs
, ...
}:
{
  options.dienilles.services.headscale = {
    enable = lib.mkEnableOption "setup headscale";
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
      opts = config.dienilles.services.headscale;
    in
    lib.mkIf opts.enable {
      sops.secrets.headscale = {
        sopsFile = opts.secretsFile;
        format = "binary";
        mode = "444";
      };

      nix-tun.storage.persist.subvolumes."headscale".directories = {
        "/db" = {
          owner = "${builtins.toString config.containers.headscale.config.users.users.headscale.uid}";
          mode = "0700";
        };
      };

      dienilles.services.traefik.services."headscale" = {
        router = {
          rule = "Host(`${opts.hostname}`)";
        };
        servers = [ "http://${config.containers.headscale.config.networking.hostName}:8080" ];
      };

      containers.headscale = {
        ephemeral = true;
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.105.10";
        localAddress = "192.168.105.11";
        bindMounts = {
          "resolv" = {
            hostPath = "/etc/resolv.conf";
            mountPoint = "/etc/resolv.conf";
          };
          "secret" = {
            hostPath = config.sops.secrets.headscale.path;
            mountPoint = config.sops.secrets.headscale.path;
          };
          "db" = {
            hostPath = "${config.nix-tun.storage.persist.path}/headscale/db";
            mountPoint = "/var/lib/headscale";
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
