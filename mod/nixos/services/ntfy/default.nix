{ lib
, config
, inputs
, pkgs
, ...
}:
{
  options.dienilles.services.ntfy = {
    enable = lib.mkEnableOption "setup ntfy";
    hostname = lib.mkOption {
      type = lib.types.str;
    };
  };

  config =
    let
      opts = config.dienilles.services.ntfy;
    in
    lib.mkIf opts.enable {
      dienilles.services.traefik.services."ntfy" = {
        router.rule = "Host(`${opts.hostname}`)";
        servers = [ "http://${config.containers.ntfy.config.networking.hostName}:8080" ];
      };

      nix-tun.storage.persist.subvolumes."ntfy".directories = {
        "/db" = {
          owner = "${builtins.toString config.containers.ntfy.config.users.users.ntfy-sh.uid}";
          mode = "0777";
        };
      };

      containers.ntfy = {
        ephemeral = true;
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.102.10";
        localAddress = "192.168.102.11";
        bindMounts = {
          "resolv" = {
            hostPath = "/etc/resolv.conf";
            mountPoint = "/etc/resolv.conf";
          };
          "db" = {
            hostPath = "${config.nix-tun.storage.persist.path}/ntfy/db";
            mountPoint = "/var/lib/ntfy";
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
