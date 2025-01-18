{ inputs
, outputs
, config
, pkgs
, lib
, ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../locale.nix
    ./disko-config.nix

    inputs.sops.nixosModules.sops
    inputs.nix-tun.nixosModules.nix-tun
    inputs.disko.nixosModules.disko

    outputs.nixosModules.dienilles
  ];

  environment.systemPackages = [
    pkgs.git
    pkgs.kitty
  ];

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    externalInterface = "enp1s0"; #TODO:change on deploy
    # Lazy IPv6 connectivity for the container
    enableIPv6 = true;
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  virtualisation.vmware.guest.enable = true;

  dienilles.nixconfig.enable = true;
  dienilles.nixconfig.allowUnfree = true;
  dienilles.bootconfig.enable = true;

  dienilles.services.openssh.enable = true;

  networking.hostName = "dienilles";

  users.defaultUserShell = pkgs.fish;

  programs.fish.enable = true;

  dienilles.services.traefik.enable = true;
  dienilles.services.traefik.staticConfigPath = ../secrets/traefik_static;
  dienilles.services.traefik.dashboardUrl = "traefik.dev.dienilles.de";
  dienilles.services.traefik.letsencryptMail = "felix@dienilles.de";
  dienilles.services.traefik.logging.enable = true;

  # Services
  nix-tun.storage.persist.enable = true;

  dienilles.services.authentik = {
    enable = true;
    hostname = "auth.dev.dienilles.de";
    envFile = ../secrets/authentik_env;
  };

  dienilles.services.prometheus = {
    enable = true;
    hostname = "prometheus.dev.dienilles.de";
    grafanaHostname = "grafana.dev.dienilles.de";
    envFile = ../secrets/prometheus_env;
  };

  dienilles.services.node_exporter = {
    enable = true;
  };

  dienilles.services.vaultwarden = {
    enable = true;
    secretsFile = ../secrets/vaultwarden;
    hostname = "vaultwarden.dev.dienilles.de";
  };

  dienilles.services.ntfy = {
    enable = true;
    hostname = "ntfy.dev.dienilles.de";
  };

  dienilles.services.mailcow = {
    enable = true;
    webmailHostname = "mail.marchcraft.de";
  };

  dienilles.services.headscale = {
    enable = true;
    hostname = "vpn.dev.dienilles.de";
    secretsFile = ../secrets/headscale;
  };

  dienilles.services.lingerie-wp = {
    enable = false;
    hostname = "lingerie-nilles.de";
    envFile = ../secrets/lingerie-wp/env;
    mariaEnvFile = ../secrets/lingerie-wp/mariaEnv;
  };

  dienilles.services.pterodactyl = {
    enable = true;
    envFile = ../secrets/pterodactyl/env;
    envFilePanel = ../secrets/pterodactyl/panel;
  };

  security.pam.sshAgentAuth.enable = true;

  dienilles.users = {
    felix = {
      shell = pkgs.fish;
      setSopsPassword = false;
      sshKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSzPwzWF8ETrEKZVrcldR5srYZB0debImh6qilNlH4va8jwVT835j4kTnwgDr/ODd5v0LagYiUVQqdC8gX/jQA9Ug9ju/NuPusyqro2g4w3r72zWFhIYlPWlJyxaP2sfUzUhnO0H2zFt/sEe8q7T+eDdHfKP+SIdeb9v9/oCAz0ZVUxCgkkK20hzhVHTXXMefjHq/zm69ygW+YpvWmvZ7liIDAaHL1/BzOtuMa3C8B5vP3FV5bh7MCSXyj5mIvPk7TG4e673fwaBYEB+2+B6traafSaSYlhHEm9H2CiRfEUa2NrBRHRv1fP4gM60350tUHLEJ8hM58LBymr3NfwxC00yODGfdaaWGxW4sxtlHw57Ev6uNvP2cN551NmdlRX7qKQKquyE4kUWHPDjJMKB8swj3F4/X6iAlGZIOW3ivcf+9fE+FUFA45MsbrijSWWnm/pOe2coP1KMvFNa6HMzCMImCAQPKpH5+LfT7eqfenDxgsJR5zm3LbrMJD6QhnBqPJsjH6gDzE17D5qctyMFy0DOad9+aVUWry1ymywSsjHuhMBcgQOgk3ZNdHIXQn5y6ejWaOJnWxZHFPKEeiwQK8LuE3cAj18p8r/rBnwhn7KHzlAgY0pgEZKrDSKIXDutFF9Y49hHyGpe3oI+oscBmH2xr0au/eNKlr/J85b9FdaQ=="
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtvtqwAan/ubiGOe01Vhda6fTlI8AP3PQQ4RsQ+GqPGjH5jVOT8WUm4a1Ed7kC26pesUgC/67wu2PhlqfhzagaPqDV+Yt/HaOSG7fB3PYLyewt66l1P/3X5gszZ5Z1NGcx0xj8sWB1Y88i9BKO3V3LbnEY/XXSgE4XxxMRlXJydt/5Hq8zodd8mXFJWWbNS+xoTM2fRcKn8Gq72qU+LTNDV8xmzLjMG/PxL/4lveKusvBMtK/V9eKkd/Mt9Wen/ICR0JlcNqxfkt+kVt+YXJhppLOiNDxVzdK88wACK1DMHxBSQjcSRC9/USicmal7hApxMB41BLqgbDmtT22Umyf1kSSicaN7+IfijoGuT084Tu5zc2YGFSAe9iRet1i4glXazrgdsk6I/3FQQc1c1eC8ni3j36/9V8FBIe7+GmL+czdR0zSnL1VMIEchps9YnVHNFOkrgMKOV84mm23Zrf7sXFme7I5oXRXXP50taqCfCUbK8uwT6S1FIZhvn23GFM3IllIH8wY7uLtpOB5TxPLmZJjgXXo8eRHqF1wnYbytU1V+MlTP6MaeWzZnOMhKEK5D9ouCTA9iYNi0cGbDJLldMcwYnd+2/kFd0p2iQcWUqebC1DnL44biNP0Hc9d8rF/jc88aotpTCVEosSTAn++b4aVdYP8TAGN5GxSWqKpnCQ== u0_a250@localhost"
      ];
    };
  };

  system.stateVersion = "23.11";
}
