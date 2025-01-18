{ lib
, config
, inputs
, pkgs
, ...
}:
{
  options.dienilles.services.node_exporter = {
    enable = lib.mkEnableOption "setup node_exporter";
  };

  config =
    let
      opts = config.dienilles.services.node_exporter;
    in
    lib.mkIf opts.enable {

      containers.node-exporter = {
        ephemeral = true;
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.101.10";
        localAddress = "192.168.101.11";
        bindMounts = {
          "resolv" = {
            hostPath = "/etc/resolv.conf";
            mountPoint = "/etc/resolv.conf";
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
