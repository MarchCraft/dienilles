{ lib
, config
, ...
}:
{
  options.dienilles.bootconfig = {
    enable = lib.mkEnableOption "auto configure the boot loader";
  };

  config =
    let
      opts = config.dienilles.bootconfig;
    in
    lib.mkIf opts.enable {
      boot.loader.systemd-boot.enable = false;
      boot.loader.efi.canTouchEfiVariables = false; # FIX:set to true when deploying to teefax
      boot.kernelParams = [ "quiet" ];

      boot.loader.grub = {
        enable = true;
      };
    };
}
