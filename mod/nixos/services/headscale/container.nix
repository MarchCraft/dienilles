{ lib
, inputs
, pkgs
, host-config
, ...
}:
{
  networking.hostName = "headscale";

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 8080;
    settings = {
      server_url = "https://${host-config.dienilles.services.headscale.hostname}";
      dns = {
        base_domain = "tailnet";
        nameservers.split."lingerie.local" = "100.64.0.4";
      };
      oidc = {
        issuer = "https://auth.dienilles.de/application/o/headscale/";
        client_secret_path = "/run/secrets/headscale";
        client_id = "pPUyvRWLduf7nFSaAqvzLvMa7YbEK3jYufQwtwZ9";
        scope = [ "openid" "profile" "email" "offline_access" ];
      };
    };
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 8080 ];
    };
    # Use systemd-resolved inside the container
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
  };

  services.resolved.enable = true;

  system.stateVersion = "23.11";
}
