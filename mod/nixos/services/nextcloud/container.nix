{
  config,
  lib,
  inputs,
  pkgs,
  host-config,
  ...
}:
{
  networking.hostName = "nextcloud";

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = host-config.dienilles.services.nextcloud.hostname;
    https = true;
    phpExtraExtensions =
      all: with all; [
        pdlib
        bz2
        smbclient
      ];
    database.createLocally = true;
    config = {
      adminpassFile = host-config.sops.secrets.nextcloud-admin-pass.path;
      dbtype = "pgsql";
    };
    settings = {
      maintenance_window_start = 4; # run background jobs from 4 AM to 8 AM
      trusted_domains = [
        host-config.containers.nextcloud.localAddress
        host-config.containers.nextcloud.hostAddress
        host-config.dienilles.services.nextcloud.hostname
        config.networking.hostName
      ];
      trusted_proxies = [
        "${host-config.containers.nextcloud.hostAddress}"
        "${host-config.containers.nextcloud.localAddress}"
        "::1"
      ];
    };
    phpOptions = {
      "opcache.jit" = "1255";
      "opcache.revalidate_freq" = "60";
      "opcache.interned_strings_buffer" = "16";
      "opcache.jit_buffer_size" = "128M";
      "apc.shm_size" = "1G";
    };
    configureRedis = true;
    caching.apcu = true;
    poolSettings = {
      pm = "dynamic";
      "pm.max_children" = "201";
      "pm.max_requests" = "500";
      "pm.max_spare_servers" = "150";
      "pm.min_spare_servers" = "50";
      "pm.start_servers" = "50";
    };
  };
  services.nginx.virtualHosts.${host-config.dienilles.services.nextcloud.hostname}.extraConfig =
    lib.mkAfter ''
      gzip_types text/javascript;
    '';

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 ];
    };
    useHostResolvConf = lib.mkForce false;
  };

  services.resolved.enable = true;

  system.stateVersion = "23.11";
}
