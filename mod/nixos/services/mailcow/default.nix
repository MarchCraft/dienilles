{ lib
, config
, pkgs
, ...
}:
{
  options.dienilles.services.mailcow =
    let
      t = lib.types;
    in
    {
      enable = lib.mkEnableOption "setup mailcow";
      webmailHostname = lib.mkOption {
        type = t.str;
      };
    };

  config =
    let
      opts = config.dienilles.services.mailcow;
    in
    lib.mkIf opts.enable {
      sops.secrets.mailcow-acme = {
        sopsFile = ../../../../nixos/secrets/mailcow/mailcow-acme;
        format = "binary";
        mode = "0400";
      };
      sops.secrets.mailcow-dockerapi = {
        sopsFile = ../../../../nixos/secrets/mailcow/mailcow-dockerapi;
        format = "binary";
        mode = "0400";
      };
      sops.secrets.mailcow-dovecot = {
        sopsFile = ../../../../nixos/secrets/mailcow/mailcow-dovecot;
        format = "binary";
        mode = "0400";
      };
      sops.secrets.mailcow-mysql = {
        sopsFile = ../../../../nixos/secrets/mailcow/mailcow-mysql;
        format = "binary";
        mode = "0400";
      };
      sops.secrets.mailcow-php-fpm = {
        sopsFile = ../../../../nixos/secrets/mailcow/mailcow-php-fpm;
        format = "binary";
        mode = "0400";
      };
      sops.secrets.mailcow-sogo = {
        sopsFile = ../../../../nixos/secrets/mailcow/mailcow-sogo;
        format = "binary";
        mode = "0400";
      };
      sops.secrets.mailcow-watchdog = {
        sopsFile = ../../../../nixos/secrets/mailcow/mailcow-watchdog;
        format = "binary";
        mode = "0400";
      };
      nix-tun.storage.persist.subvolumes."mailcow".directories = {
        "/crypt" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/mysql" = {
          owner = "999"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/mysql-socket" = {
          owner = "999"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/clamd-db" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/rspamd" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/vmail-index" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/vmail-vol" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/sogo-web" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/sogo-userdata-backup" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/postfix" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/redis" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
        "/solr" = {
          owner = "1000"; # TODO: Set the correct owner and mode
          mode = "0777";
        };
      };

      # Runtime
      virtualisation.docker = {
        enable = true;
        autoPrune.enable = true;
        daemon.settings = {
          ipv6 = true;
          fixed-cidr-v6 = "fd00:dead:beef:c0::/80";
          experimental = true;
          ip6tables = true;
        };
      };
      virtualisation.oci-containers.backend = "docker";

      # Containers

      # Containers
      virtualisation.oci-containers.containers."mailcow-acme-mailcow" = {
        image = "mailcow/acme:1.90";
        environment = {
          "ACME_CONTACT" = "felix@dienilles.de";
          "ADDITIONAL_SAN" = "";
          "AUTODISCOVER_SAN" = "y";
          "COMPOSE_PROJECT_NAME" = "mailcow";
          "DBNAME" = "mailcow";
          "DBUSER" = "mailcow";
          "DIRECTORY_URL" = "";
          "ENABLE_SSL_SNI" = "n";
          "LE_STAGING" = "n";
          "LOG_LINES" = "9999";
          "MAILCOW_HOSTNAME" = "mail.marchcraft.de";
          "ONLY_MAILCOW_HOSTNAME" = "n";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "SKIP_HTTP_VERIFICATION" = "n";
          "SKIP_IP_CHECK" = "n";
          "SKIP_LETS_ENCRYPT" = "n";
          "SNAT6_TO_SOURCE" = "n";
          "SNAT_TO_SOURCE" = "n";
          "TZ" = "Europe/Berlin";
        };
        environmentFiles = [ config.sops.secrets.mailcow-acme.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/ssl:/var/lib/acme:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/ssl-example:/var/lib/ssl-example:ro,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/web/.well-known/acme-challenge:/var/www/acme:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql-socket:/var/run/mysqld:rw"
        ];
        dependsOn = [
          "mailcow-nginx-mailcow"
          "mailcow-unbound-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--network-alias=acme"
          "--network-alias=acme-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-acme-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-clamd-mailcow" = {
        image = "mailcow/clamd:1.66";
        environment = {
          "SKIP_CLAMD" = "n";
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/clamav:/etc/clamav:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/clamd-db:/var/lib/clamav:rw"
        ];
        dependsOn = [
          "mailcow-unbound-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--network-alias=clamd"
          "--network-alias=clamd-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-clamd-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-dockerapi-mailcow" = {
        image = "mailcow/dockerapi:2.09";
        environment = {
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "TZ" = "Europe/Berlin";
        };
        environmentFiles = [ config.sops.secrets.mailcow-dockerapi.path ];
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ];
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--network-alias=dockerapi"
          "--network-alias=dockerapi-mailcow"
          "--network=mailcow_mailcow-network"
          "--security-opt=label=disable"
        ];
      };
      systemd.services."docker-mailcow-dockerapi-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-dovecot-mailcow" = {
        image = "mailcow/dovecot:2.2";
        environment = {
          "ACL_ANYONE" = "disallow";
          "ALLOW_ADMIN_EMAIL_LOGIN" = "n";
          "COMPOSE_PROJECT_NAME" = "mailcow";
          "DBNAME" = "mailcow";
          "DBUSER" = "mailcow";
          "DOVEADM_REPLICA_PORT" = "";
          "DOVECOT_MASTER_PASS" = "";
          "DOVECOT_MASTER_USER" = "";
          "FLATCURVE_EXPERIMENTAL" = "n";
          "IPV4_NETWORK" = "172.22.1";
          "LOG_LINES" = "9999";
          "MAILCOW_HOSTNAME" = "mail.marchcraft.de";
          "MAILCOW_PASS_SCHEME" = "BLF-CRYPT";
          "MAILCOW_REPLICA_IP" = "";
          "MAILDIR_GC_TIME" = "7200";
          "MAILDIR_SUB" = "";
          "MASTER" = "y";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "SKIP_SOLR" = "y";
          "TZ" = "Europe/Berlin";
        };
        environmentFiles = [ config.sops.secrets.mailcow-dovecot.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/ssl:/etc/ssl/mail:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/templates:/templates:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/dovecot:/etc/dovecot:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/phpfpm/sogo-sso:/etc/phpfpm:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/custom:/etc/rspamd/custom:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/sogo:/etc/sogo:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/hooks/dovecot:/hooks:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/crypt:/mail_crypt:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql-socket:/var/run/mysqld:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/rspamd:/var/lib/rspamd:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/vmail-index:/var/vmail_index:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/vmail-vol:/var/vmail:rw"
          "/dev/console:/dev/console:rw"
        ];
        ports = [
          "127.0.0.1:19991:12345/tcp"
          "143:143/tcp"
          "993:993/tcp"
          "110:110/tcp"
          "995:995/tcp"
          "4190:4190/tcp"
        ];
        labels = {
          "ofelia.enabled" = "true";
          "ofelia.job-exec.dovecot_clean_q_aged.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu vmail /usr/local/bin/clean_q_aged.sh || exit 0\"";
          "ofelia.job-exec.dovecot_clean_q_aged.schedule" = "@every 24h";
          "ofelia.job-exec.dovecot_fts.command" = "/bin/bash -c \"/usr/local/bin/gosu vmail /usr/local/bin/optimize-fts.sh\"";
          "ofelia.job-exec.dovecot_fts.schedule" = "@every 24h";
          "ofelia.job-exec.dovecot_imapsync_runner.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu nobody /usr/local/bin/imapsync_runner.pl || exit 0\"";
          "ofelia.job-exec.dovecot_imapsync_runner.no-overlap" = "true";
          "ofelia.job-exec.dovecot_imapsync_runner.schedule" = "@every 1m";
          "ofelia.job-exec.dovecot_maildir_gc.command" = "/bin/bash -c \"source /source_env.sh ; /usr/local/bin/gosu vmail /usr/local/bin/maildir_gc.sh\"";
          "ofelia.job-exec.dovecot_maildir_gc.schedule" = "@every 30m";
          "ofelia.job-exec.dovecot_quarantine.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu vmail /usr/local/bin/quarantine_notify.py || exit 0\"";
          "ofelia.job-exec.dovecot_quarantine.schedule" = "@every 20m";
          "ofelia.job-exec.dovecot_repl_health.command" = "/bin/bash -c \"/usr/local/bin/gosu vmail /usr/local/bin/repl_health.sh\"";
          "ofelia.job-exec.dovecot_repl_health.schedule" = "@every 5m";
          "ofelia.job-exec.dovecot_sarules.command" = "/bin/bash -c \"/usr/local/bin/sa-rules.sh\"";
          "ofelia.job-exec.dovecot_sarules.schedule" = "@every 24h";
          "ofelia.job-exec.dovecot_trim_logs.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu vmail /usr/local/bin/trim_logs.sh || exit 0\"";
          "ofelia.job-exec.dovecot_trim_logs.schedule" = "@every 1m";
        };
        dependsOn = [
          "mailcow-mysql-mailcow"
          "mailcow-netfilter-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--cap-add=NET_BIND_SERVICE"
          "--dns=172.22.1.254"
          "--ip=172.22.1.250"
          "--network-alias=dovecot"
          "--network-alias=dovecot-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-dovecot-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-ipv6nat-mailcow" = {
        image = "robbertkl/ipv6nat";
        environment = {
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "/lib/modules:/lib/modules:ro"
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ];
        dependsOn = [
          "mailcow-acme-mailcow"
          "mailcow-clamd-mailcow"
          "mailcow-dockerapi-mailcow"
          "mailcow-dovecot-mailcow"
          "mailcow-memcached-mailcow"
          "mailcow-mysql-mailcow"
          "mailcow-netfilter-mailcow"
          "mailcow-nginx-mailcow"
          "mailcow-php-fpm-mailcow"
          "mailcow-postfix-mailcow"
          "mailcow-redis-mailcow"
          "mailcow-rspamd-mailcow"
          "mailcow-sogo-mailcow"
          "mailcow-solr-mailcow"
          "mailcow-unbound-mailcow"
          "mailcow-watchdog-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network=host"
          "--privileged"
          "--security-opt=label=disable"
        ];
      };
      systemd.services."docker-mailcow-ipv6nat-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-memcached-mailcow" = {
        image = "memcached:alpine";
        environment = {
          "TZ" = "Europe/Berlin";
        };
        log-driver = "journald";
        extraOptions = [
          "--network-alias=memcached"
          "--network-alias=memcached-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-memcached-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-mysql-mailcow" = {
        image = "mariadb:10.5";
        environment = {
          "MYSQL_DATABASE" = "mailcow";
          "MYSQL_INITDB_SKIP_TZINFO" = "1";
          "MYSQL_USER" = "mailcow";
          "TZ" = "Europe/Berlin";
        };
        labels = {
          "com.docker.compose.service" = "mysql-mailcow";
          "com.docker.compose.project" = "mailcow";
        };
        environmentFiles = [ config.sops.secrets.mailcow-mysql.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/mysql:/etc/mysql/conf.d:ro,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql-socket:/var/run/mysqld:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql:/var/lib/mysql:rw"
        ];
        ports = [
          "127.0.0.1:13306:3306/tcp"
        ];
        dependsOn = [
          "mailcow-netfilter-mailcow"
          "mailcow-unbound-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=mysql"
          "--network-alias=mysql-mailcow"
          "--network=mailcow_mailcow-network"
          "--name=mysql-mailcow"
        ];
      };
      systemd.services."docker-mailcow-mysql-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-netfilter-mailcow" = {
        image = "mailcow/netfilter:1.59";
        environment = {
          "DISABLE_NETFILTER_ISOLATION_RULE" = "y";
          "IPV4_NETWORK" = "172.22.1";
          "IPV6_NETWORK" = "fd4d:6169:6c63:6f77::/64";
          "MAILCOW_REPLICA_IP" = "";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "SNAT6_TO_SOURCE" = "n";
          "SNAT_TO_SOURCE" = "n";
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "/lib/modules:/lib/modules:ro"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network=host"
          "--privileged"
        ];
      };
      systemd.services."docker-mailcow-netfilter-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-nginx-mailcow" = {
        image = "nginx:mainline-alpine";
        environment = {
          "ADDITIONAL_SERVER_NAMES" = "";
          "ALLOW_ADMIN_EMAIL_LOGIN" = "n";
          "HTTPS_PORT" = "443";
          "HTTP_PORT" = "80";
          "IPV4_NETWORK" = "172.22.1";
          "MAILCOW_HOSTNAME" = "mail.marchcraft.de";
          "SKIP_SOGO" = "n";
          "TZ" = "Europe/Berlin";
        };
        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.mailcow.entrypoints" = "websecure";
          "traefik.http.routers.mailcow.rule" = "Host(`${opts.webmailHostname}`)";
          "traefik.http.routers.mailcow.tls" = "true";
          "traefik.http.routers.mailcow.tls.certresolver" = "letsencrypt";
          "traefik.http.services.mailcow.loadbalancer.server.port" = "80";
          # "traefik.http.services.nawi.loadbalancer.healthCheck.path" = "/";
        };
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/ssl:/etc/ssl/mail:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/nginx:/etc/nginx/conf.d:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/dynmaps:/dynmaps:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/meta_exporter:/meta_exporter:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/web:/web:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/sogo-web:/usr/lib/GNUstep/SOGo:rw"
        ];
        cmd = [ "/bin/sh" "-c" "envsubst < /etc/nginx/conf.d/templates/listen_plain.template > /etc/nginx/conf.d/listen_plain.active && envsubst < /etc/nginx/conf.d/templates/listen_ssl.template > /etc/nginx/conf.d/listen_ssl.active && envsubst < /etc/nginx/conf.d/templates/sogo.template > /etc/nginx/conf.d/sogo.active && . /etc/nginx/conf.d/templates/server_name.template.sh > /etc/nginx/conf.d/server_name.active && . /etc/nginx/conf.d/templates/sites.template.sh > /etc/nginx/conf.d/sites.active && . /etc/nginx/conf.d/templates/sogo_eas.template.sh > /etc/nginx/conf.d/sogo_eas.active && nginx -qt && until ping phpfpm -c1 > /dev/null; do sleep 1; done && until ping sogo -c1 > /dev/null; do sleep 1; done && until ping redis -c1 > /dev/null; do sleep 1; done && until ping rspamd -c1 > /dev/null; do sleep 1; done && exec nginx -g 'daemon off;'" ];
        dependsOn = [
          "mailcow-php-fpm-mailcow"
          "mailcow-redis-mailcow"
          "mailcow-sogo-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--network-alias=nginx"
          "--network-alias=nginx-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-nginx-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-ofelia-mailcow" = {
        image = "mcuadros/ofelia:latest";
        environment = {
          "COMPOSE_PROJECT_NAME" = "mailcow";
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ];
        cmd = [ "daemon" "--docker" "-f" "label=com.docker.compose.project=mailcow" ];
        labels = {
          "ofelia.enabled" = "true";
        };
        dependsOn = [
          "mailcow-dovecot-mailcow"
          "mailcow-sogo-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=ofelia"
          "--network-alias=ofelia-mailcow"
          "--network=mailcow_mailcow-network"
          "--security-opt=label=disable"
        ];
      };
      systemd.services."docker-mailcow-ofelia-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-olefy-mailcow" = {
        image = "mailcow/olefy:1.13";
        environment = {
          "OLEFY_BINDADDRESS" = "0.0.0.0";
          "OLEFY_BINDPORT" = "10055";
          "OLEFY_DEL_TMP" = "1";
          "OLEFY_LOGLVL" = "20";
          "OLEFY_MINLENGTH" = "500";
          "OLEFY_OLEVBA_PATH" = "/usr/bin/olevba";
          "OLEFY_PYTHON_PATH" = "/usr/bin/python3";
          "OLEFY_TMPDIR" = "/tmp";
          "TZ" = "Europe/Berlin";
        };
        log-driver = "journald";
        extraOptions = [
          "--network-alias=olefy"
          "--network-alias=olefy-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-olefy-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-php-fpm-mailcow" = {
        image = "mailcow/phpfpm:1.91.1";
        environment = {
          "ALLOW_ADMIN_EMAIL_LOGIN" = "n";
          "API_ALLOW_FROM" = "invalid";
          "API_KEY" = "invalid";
          "API_KEY_READ_ONLY" = "invalid";
          "CLUSTERMODE" = "";
          "COMPOSE_PROJECT_NAME" = "mailcow";
          "DBNAME" = "mailcow";
          "DBUSER" = "mailcow";
          "DEMO_MODE" = "n";
          "DEV_MODE" = "n";
          "FLATCURVE_EXPERIMENTAL" = "";
          "IMAPS_PORT" = "993";
          "IMAP_PORT" = "143";
          "IPV4_NETWORK" = "172.22.1";
          "IPV6_NETWORK" = "fd4d:6169:6c63:6f77::/64";
          "LOG_LINES" = "9999";
          "MAILCOW_HOSTNAME" = "mail.marchcraft.de";
          "MAILCOW_PASS_SCHEME" = "BLF-CRYPT";
          "MASTER" = "y";
          "POPS_PORT" = "995";
          "POP_PORT" = "110";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "SIEVE_PORT" = "4190";
          "SKIP_CLAMD" = "n";
          "SKIP_SOGO" = "n";
          "SKIP_SOLR" = "y";
          "SMTPS_PORT" = "465";
          "SMTP_PORT" = "25";
          "SUBMISSION_PORT" = "587";
          "TZ" = "Europe/Berlin";
          "WEBAUTHN_ONLY_TRUSTED_VENDORS" = "n";
        };
        environmentFiles = [ config.sops.secrets.mailcow-php-fpm.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/templates:/tpls:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/dovecot/global_sieve_after:/global_sieve/after:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/dovecot/global_sieve_before:/global_sieve/before:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/nginx:/etc/nginx/conf.d:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/phpfpm/php-conf.d/opcache-recommended.ini:/usr/local/etc/php/conf.d/opcache-recommended.ini:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/phpfpm/php-conf.d/other.ini:/usr/local/etc/php/conf.d/zzz-other.ini:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/phpfpm/php-conf.d/upload.ini:/usr/local/etc/php/conf.d/upload.ini:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/phpfpm/php-fpm.d/pools.conf:/usr/local/etc/php-fpm.d/z-pools.conf:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/phpfpm/sogo-sso:/etc/sogo-sso:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/custom:/rspamd_custom_maps:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/dynmaps:/dynmaps:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/meta_exporter:/meta_exporter:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/sogo:/etc/sogo:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/hooks/phpfpm:/hooks:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/web:/web:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql-socket:/var/run/mysqld:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/rspamd:/var/lib/rspamd:rw"
        ];
        cmd = [ "php-fpm" "-d" "date.timezone=Europe/Berlin" "-d" "expose_php=0" ];
        dependsOn = [
          "mailcow-redis-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--network-alias=php-fpm-mailcow"
          "--network-alias=phpfpm"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-php-fpm-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-postfix-mailcow" = {
        image = "mailcow/postfix:1.77";
        environment = {
          "DBNAME" = "mailcow";
          "DBPASS" = "eEofEWbWWcB5gOW62YkFkvV7mSXR";
          "DBUSER" = "mailcow";
          "LOG_LINES" = "9999";
          "MAILCOW_HOSTNAME" = "mail.marchcraft.de";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "SPAMHAUS_DQS_KEY" = "";
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/ssl:/etc/ssl/mail:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/postfix:/opt/postfix/conf:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/hooks/postfix:/hooks:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/crypt:/var/lib/zeyple:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql-socket:/var/run/mysqld:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/postfix:/var/spool/postfix:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/rspamd:/var/lib/rspamd:rw"
        ];
        ports = [
          "25:25/tcp"
          "465:465/tcp"
          "587:587/tcp"
        ];
        dependsOn = [
          "mailcow-mysql-mailcow"
          "mailcow-unbound-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--cap-add=NET_BIND_SERVICE"
          "--dns=172.22.1.254"
          "--ip=172.22.1.253"
          "--network-alias=postfix"
          "--network-alias=postfix-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-postfix-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-redis-mailcow" = {
        image = "redis:7-alpine";
        environment = {
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/redis:/data:rw"
        ];
        ports = [
          "127.0.0.1:7654:6379/tcp"
        ];
        dependsOn = [
          "mailcow-netfilter-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--ip=172.22.1.249"
          "--network-alias=redis"
          "--network-alias=redis-mailcow"
          "--network=mailcow_mailcow-network"
          "--sysctl=net.core.somaxconn=4096"
        ];
      };
      systemd.services."docker-mailcow-redis-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-rspamd-mailcow" = {
        image = "mailcow/rspamd:1.98";
        environment = {
          "IPV4_NETWORK" = "172.22.1";
          "IPV6_NETWORK" = "fd4d:6169:6c63:6f77::/64";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "SPAMHAUS_DQS_KEY" = "";
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/custom:/etc/rspamd/custom:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/local.d:/etc/rspamd/local.d:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/lua:/etc/rspamd/lua:ro,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/override.d:/etc/rspamd/override.d:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/plugins.d:/etc/rspamd/plugins.d:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/rspamd.conf.local:/etc/rspamd/rspamd.conf.local:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/rspamd/rspamd.conf.override:/etc/rspamd/rspamd.conf.override:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/hooks/rspamd:/hooks:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/rspamd:/var/lib/rspamd:rw"
        ];
        dependsOn = [
          "mailcow-clamd-mailcow"
          "mailcow-dovecot-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--hostname=rspamd"
          "--network-alias=rspamd"
          "--network-alias=rspamd-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-rspamd-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-sogo-mailcow" = {
        image = "mailcow/sogo:1.127.1";
        environment = {
          "ACL_ANYONE" = "disallow";
          "ALLOW_ADMIN_EMAIL_LOGIN" = "n";
          "DBNAME" = "mailcow";
          "DBUSER" = "mailcow";
          "IPV4_NETWORK" = "172.22.1";
          "LOG_LINES" = "9999";
          "MAILCOW_HOSTNAME" = "mail.marchcraft.de";
          "MAILCOW_PASS_SCHEME" = "BLF-CRYPT";
          "MASTER" = "y";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "SKIP_SOGO" = "n";
          "SOGO_EXPIRE_SESSION" = "480";
          "TZ" = "Europe/Berlin";
        };
        environmentFiles = [ config.sops.secrets.mailcow-sogo.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/sogo:/etc/sogo:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/sogo/custom-favicon.ico:/usr/lib/GNUstep/SOGo/WebServerResources/img/sogo.ico:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/sogo/custom-sogo.js:/usr/lib/GNUstep/SOGo/WebServerResources/js/custom-sogo.js:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/sogo/custom-theme.js:/usr/lib/GNUstep/SOGo/WebServerResources/js/theme.js:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/hooks/sogo:/hooks:rw,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/web/inc/init_db.inc.php:/init_db.inc.php:rw,z"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql-socket:/var/run/mysqld:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/sogo-userdata-backup:/sogo_backup:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/sogo-web:/sogo_web:rw"
        ];
        labels = {
          "ofelia.enabled" = "true";
          "ofelia.job-exec.sogo_backup.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-tool backup /sogo_backup ALL || exit 0\"";
          "ofelia.job-exec.sogo_backup.schedule" = "@every 24h";
          "ofelia.job-exec.sogo_ealarms.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-ealarms-notify -p /etc/sogo/cron.creds || exit 0\"";
          "ofelia.job-exec.sogo_ealarms.schedule" = "@every 1m";
          "ofelia.job-exec.sogo_eautoreply.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-tool update-autoreply -p /etc/sogo/cron.creds || exit 0\"";
          "ofelia.job-exec.sogo_eautoreply.schedule" = "@every 5m";
          "ofelia.job-exec.sogo_sessions.command" = "/bin/bash -c \"[[ \${MASTER} == y ]] && /usr/local/bin/gosu sogo /usr/sbin/sogo-tool -v expire-sessions \${SOGO_EXPIRE_SESSION} || exit 0\"";
          "ofelia.job-exec.sogo_sessions.schedule" = "@every 1m";
        };
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--ip=172.22.1.248"
          "--network-alias=sogo"
          "--network-alias=sogo-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-sogo-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-solr-mailcow" = {
        image = "mailcow/solr:1.8.3";
        environment = {
          "FLATCURVE_EXPERIMENTAL" = "n";
          "SKIP_SOLR" = "n";
          "SOLR_HEAP" = "1024";
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/solr:/opt/solr/server/solr/dovecot-fts/data:rw"
        ];
        ports = [
          "127.0.0.1:18983:8983/tcp"
        ];
        dependsOn = [
          "mailcow-netfilter-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--network-alias=solr"
          "--network-alias=solr-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-solr-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-unbound-mailcow" = {
        image = "mailcow/unbound:1.23";
        environment = {
          "SKIP_UNBOUND_HEALTHCHECK" = "n";
          "TZ" = "Europe/Berlin";
        };
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/conf/unbound/unbound.conf:/etc/unbound/unbound.conf:ro,Z"
          "${config.nix-tun.storage.persist.path}/mailcow/data/hooks/unbound:/hooks:rw,Z"
        ];
        log-driver = "journald";
        extraOptions = [
          "--ip=172.22.1.254"
          "--network-alias=unbound"
          "--network-alias=unbound-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-unbound-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };
      virtualisation.oci-containers.containers."mailcow-watchdog-mailcow" = {
        image = "mailcow/watchdog:2.05";
        environment = {
          "ACME_THRESHOLD" = "1";
          "CHECK_UNBOUND" = "1";
          "CLAMD_THRESHOLD" = "15";
          "COMPOSE_PROJECT_NAME" = "mailcow";
          "DBNAME" = "mailcow";
          "DBUSER" = "mailcow";
          "DOVECOT_REPL_THRESHOLD" = "20";
          "DOVECOT_THRESHOLD" = "12";
          "EXTERNAL_CHECKS_THRESHOLD" = "1";
          "FAIL2BAN_THRESHOLD" = "1";
          "HTTPS_PORT" = "443";
          "IPV4_NETWORK" = "172.22.1";
          "IPV6_NETWORK" = "fd4d:6169:6c63:6f77::/64";
          "IP_BY_DOCKER_API" = "0";
          "LOG_LINES" = "9999";
          "MAILCOW_HOSTNAME" = "mail.marchcraft.de";
          "MAILQ_CRIT" = "30";
          "MAILQ_THRESHOLD" = "20";
          "MYSQL_REPLICATION_THRESHOLD" = "1";
          "MYSQL_THRESHOLD" = "5";
          "NGINX_THRESHOLD" = "5";
          "OLEFY_THRESHOLD" = "5";
          "PHPFPM_THRESHOLD" = "5";
          "POSTFIX_THRESHOLD" = "8";
          "RATELIMIT_THRESHOLD" = "1";
          "REDIS_SLAVEOF_IP" = "";
          "REDIS_SLAVEOF_PORT" = "";
          "REDIS_THRESHOLD" = "5";
          "RSPAMD_THRESHOLD" = "5";
          "SKIP_CLAMD" = "n";
          "SKIP_LETS_ENCRYPT" = "n";
          "SKIP_SOGO" = "n";
          "SOGO_THRESHOLD" = "3";
          "TZ" = "Europe/Berlin";
          "UNBOUND_THRESHOLD" = "5";
          "USE_WATCHDOG" = "n";
          "WATCHDOG_EXTERNAL_CHECKS" = "n";
          "WATCHDOG_MYSQL_REPLICATION_CHECKS" = "n";
          "WATCHDOG_NOTIFY_BAN" = "y";
          "WATCHDOG_NOTIFY_EMAIL" = "";
          "WATCHDOG_NOTIFY_START" = "y";
          "WATCHDOG_NOTIFY_WEBHOOK" = "";
          "WATCHDOG_NOTIFY_WEBHOOK_BODY" = "";
          "WATCHDOG_SUBJECT" = "Watchdog ALERT";
          "WATCHDOG_VERBOSE" = "n";
        };
        environmentFiles = [ config.sops.secrets.mailcow-watchdog.path ];
        volumes = [
          "${config.nix-tun.storage.persist.path}/mailcow/data/assets/ssl:/etc/ssl/mail:ro,z"
          "${config.nix-tun.storage.persist.path}/mailcow/mysql-socket:/var/run/mysqld:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/postfix:/var/spool/postfix:rw"
          "${config.nix-tun.storage.persist.path}/mailcow/rspamd:/var/lib/rspamd:rw"
        ];
        dependsOn = [
          "mailcow-acme-mailcow"
          "mailcow-dovecot-mailcow"
          "mailcow-mysql-mailcow"
          "mailcow-postfix-mailcow"
          "mailcow-redis-mailcow"
        ];
        log-driver = "journald";
        extraOptions = [
          "--dns=172.22.1.254"
          "--network-alias=watchdog"
          "--network-alias=watchdog-mailcow"
          "--network=mailcow_mailcow-network"
        ];
      };
      systemd.services."docker-mailcow-watchdog-mailcow" = {
        serviceConfig = {
          Restart = lib.mkOverride 90 "always";
          RestartMaxDelaySec = lib.mkOverride 90 "1m";
          RestartSec = lib.mkOverride 90 "100ms";
          RestartSteps = lib.mkOverride 90 9;
        };
        after = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        requires = [
          "docker-network-mailcow_mailcow-network.service"
        ];
        partOf = [
          "docker-compose-mailcow-root.target"
        ];
        wantedBy = [
          "docker-compose-mailcow-root.target"
        ];
      };

      # Networks
      systemd.services."docker-network-mailcow_mailcow-network" = {
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "docker network rm -f mailcow_mailcow-network";
        };
        script = ''
          docker network inspect mailcow_mailcow-network || docker network create mailcow_mailcow-network --driver=bridge --opt=com.docker.network.bridge.name=br-mailcow --subnet=172.22.1.0/24 --subnet=fd4d:6169:6c63:6f77::/64
        '';
        partOf = [ "docker-compose-mailcow-root.target" ];
        wantedBy = [ "docker-compose-mailcow-root.target" ];
      };

      # Root service
      # When started, this will automatically create all resources and start
      # the containers. When stopped, this will teardown all resources.
      systemd.targets."docker-compose-mailcow-root" = {
        unitConfig = {
          Description = "Root target generated by compose2nix.";
        };
        wantedBy = [ "multi-user.target" ];
      };

    };
}
