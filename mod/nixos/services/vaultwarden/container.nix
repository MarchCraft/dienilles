{ lib
, inputs
, pkgs
, host-config
, ...
}:
{
  networking.hostName = "vaultwarden";

  services.vaultwarden = {
    enable = true;
    environmentFile = host-config.sops.secrets.vaultwarden.path;
    config = {
      DOMAIN = "https://pass.dienilles.de";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8222;
      ORG_CREATION_USERS = "all";

      ROCKET_LOG = "critical";

      SMTP_HOST = "email.dienilles.de";
      SMTP_PORT = 465;
      SMTP_SECURITY = "force_tls";

      SMTP_FROM = "felix@marchcraft.de";
      SMTP_FROM_NAME = "DieNilles Password Manager";
      SMTP_USERNAME = "felix@marchcraft.de";
    };
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 8222 ];
    };
    # Use systemd-resolved inside the container
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
  };

  services.resolved.enable = true;

  system.stateVersion = "23.11";
}
