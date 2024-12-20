{ lib
, config
, ...
}:
{
  options.dienilles.services.openssh.enable = lib.mkEnableOption "enable openssh";

  config = lib.mkIf config.dienilles.services.openssh.enable {
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };

    networking.firewall = {
      enable = true;
    };
  };
}
