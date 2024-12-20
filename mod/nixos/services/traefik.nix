{ config
, pkgs
, sops
, lib
, ...
}:
{
  options.dienilles.services.traefik = {
    enable = lib.mkEnableOption "Enable the Traefik Reverse Proxy";
    letsencryptMail = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = ''
        The email address used for letsencrypt certificates
      '';
    };
    dashboardUrl = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = ''
        The url to which the dashboard should be published to
      '';
    };
    staticConfigPath = lib.mkOption {
      type = lib.types.path;
      description = ''
        The path to the static configuration ENV file
      '';
    };
    redirects =
      let
        redirectOpts = lib.types.submodule {
          options = {
            from = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = '''';
            };
            to = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = '''';
            };
          };
        };
      in
      lib.mkOption {
        type = lib.types.attrsOf redirectOpts;
        default = { };
        description = '''';
      };
    entrypoints = lib.mkOption {
      type = lib.types.attrs;
      default = {
        web = {
          port = 80;
          http = {
            redirections = {
              entryPoint = {
                to = "websecure";
                scheme = "https";
              };
            };
          };
        };
        websecure = {
          port = 443;
        };
      };
      description = ''
        The entrypoints of the traefik reverse proxy default are 80 (web) and 443 (websecure)
      '';
    };
    logging = {
      enable = lib.mkEnableOption "enable logging";
      filePath = lib.mkOption {
        type = lib.types.str;
        default = "/var/log/traefik.log";
      };
    };
    services =
      let
        serviceOpts = lib.types.submodule {
          options = {
            router = {
              rule = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = ''
                  The routing rule for this service. The rules are defined here: https://doc.traefik.io/traefik/routing/routers/
                '';
              };
              priority = lib.mkOption {
                type = lib.types.int;
                default = 0;
              };
              tls = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = ''
                    Enable tls for router, default = true;
                  '';
                };
                options = lib.mkOption {
                  type = lib.types.attrs;
                  default = {
                    certResolver = "letsencrypt";
                  };
                  description = ''
                    Options for tls, default is to use the letsencrypt certResolver
                  '';
                };
              };
              middlewares = lib.mkOption {
                type = lib.types.listOf (lib.types.str);
                default = [ ];
                description = ''
                  The middlewares applied to the router, the middlewares are applied in order.
                '';
              };
              entryPoints = lib.mkOption {
                type = lib.types.listOf (lib.types.str);
                default = [ "websecure" ];
                description = ''
                  The Entrypoint of the service, default is 443 (websecure)
                '';
              };
            };
            servers = lib.mkOption {
              type = lib.types.listOf (lib.types.str);
              default = [ ];
              description = ''
                The hosts of the service
              '';
            };
            healthCheck = {
              enable = lib.mkEnableOption {
                default = false;
                description = ''
                  Enable the HealthCheck for this serviceOpts
                '';
              };
              path = lib.mkOption {
                type = lib.types.str;
                default = "/";
                description = ''
                  set the Healthcheck Path
                '';
              };
              interval = lib.mkOption {
                type = lib.types.str;
                default = "10s";
                description = ''
                  set the Healthcheck Interval
                '';
              };
            };
          };
        };
      in
      lib.mkOption {
        type = lib.types.attrsOf serviceOpts;
        default = { };
        description = ''
          A simple setup to configure http loadBalancer services and routers.
        '';
      };
  };

  config = lib.mkIf config.dienilles.services.traefik.enable {
    sops.secrets.traefik = {
      format = "binary";
      mode = "444";
      sopsFile = ../../../nixos/secrets/traefik;
    };

    users.users.traefik.extraGroups = [ "docker" ];
    networking.firewall.allowedTCPPorts = lib.attrsets.mapAttrsToList
      (
        name: value: value.port
      )
      config.dienilles.services.traefik.entrypoints;

    sops.secrets.traefik_static = {
      sopsFile = config.dienilles.services.traefik.staticConfigPath;
      format = "binary";
      mode = "444";
    };

    services.traefik =
      let

        dynamicConfig =
          pkgs.runCommand "config.toml"
            {
              buildInputs = [ pkgs.remarshal ];
              preferLocalBuild = true;
            }
            ''
              remarshal -if json -of toml \
                < ${pkgs.writeText "dynamic_config.json" (builtins.toJSON config.services.traefik.dynamicConfigOptions)} \
                > $out
            '';

        configDir = pkgs.runCommandLocal "traefik-config-dir" { } ''
          mkdir $out
          ln -s ${dynamicConfig} $out/dyn_config.toml
          ln -s ${config.sops.secrets.traefik.path} $out/dyn_sops.toml
        '';
      in
      {
        enable = true;

        environmentFiles = [ config.sops.secrets.traefik_static.path ];

        dynamicConfigOptions = {
          http = {
            routers =
              (lib.attrsets.mapAttrs
                (
                  name: value:
                    lib.mkMerge [
                      {
                        rule = value.router.rule;
                        priority = value.router.priority;
                        middlewares = value.router.middlewares;
                        service = name;
                        entryPoints = value.router.entryPoints;
                      }
                      (lib.mkIf value.router.tls.enable {
                        tls = value.router.tls.options;
                      })
                    ]
                )
                config.dienilles.services.traefik.services)
              // lib.attrsets.mapAttrs
                (name: value: {
                  service = "blank";
                  priority = 10;
                  rule = "Host(`${builtins.replaceStrings [ "." ] [ "\." ] value.from}`)";
                  middlewares = name;
                  tls.certResolver = "letsencrypt";
                })
                config.dienilles.services.traefik.redirects
              // {
                dashboard = {
                  rule = "Host(`${config.dienilles.services.traefik.dashboardUrl}`)";
                  service = "api@internal";
                  entryPoints = [ "websecure" ];
                  middlewares = [ "authentik" ];
                  tls.certResolver = "letsencrypt";
                };
              };
            middlewares =
              lib.attrsets.mapAttrs
                (name: value: {
                  redirectRegex = {
                    regex = "(www\\.)?${builtins.replaceStrings [ "." ] [ "\." ] value.from}/?";
                    replacement = value.to;
                    permanent = true;
                  };
                })
                config.dienilles.services.traefik.redirects
              // {
                authentik.forwardAuth = {
                  address = "https://authentik:9443/outpost.goauthentik.io/auth/traefik";
                  trustForwardHeader = true;
                  tls.insecureSkipVerify = true;
                  authResponseHeaders = [
                    "X-authentik-username"
                    "X-authentik-groups"
                    "X-authentik-email"
                    "X-authentik-name"
                    "X-authentik-uid"
                    "X-authentik-jwt"
                    "X-authentik-meta-jwks"
                    "X-authentik-meta-outpost"
                    "X-authentik-meta-provider"
                    "X-authentik-meta-app"
                    "X-authentik-meta-version"
                  ];
                };
              };
            services =
              lib.attrsets.mapAttrs
                (name: value: {
                  loadBalancer = lib.mkMerge [
                    {
                      servers = builtins.map
                        (value: {
                          url = value;
                        })
                        value.servers;
                    }
                    (lib.mkIf value.healthCheck.enable {
                      healthCheck = {
                        path = value.healthCheck.path;
                        interval = value.healthCheck.interval;
                      };
                    })
                  ];
                })
                config.dienilles.services.traefik.services
              // {
                blank = {
                  loadBalancer = {
                    servers = {
                      url = "about:blank";
                    };
                  };
                };
              };
          };
        };
        staticConfigOptions = {
          serversTransport.insecureSkipVerify = true;
          metrics.prometheus = {
            entryPoint = "metrics";
            buckets = [
              0.1
              0.3
              1.2
              5.0
            ];
            addEntryPointsLabels = true;
            addServicesLabels = true;
          };
          providers.file.directory = configDir;
          providers.docker = {
            exposedByDefault = false;
            watch = true;
          };
          ping = {
            entryPoint = "ping";
          };
          log.level = "DEBUG";
          accesslog = lib.mkIf config.dienilles.services.traefik.logging.enable {
            filePath = config.dienilles.services.traefik.logging.filePath;
          };
          certificatesResolvers = {
            letsencrypt = {
              acme = {
                email = config.dienilles.services.traefik.letsencryptMail;
                storage = "/var/lib/traefik/acme.json";
                tlsChallenge = { };
              };
            };
          };

          entryPoints =
            lib.attrsets.filterAttrs (n: v: n != "port")
              (
                lib.attrsets.mapAttrs
                  (
                    name: value:
                      lib.attrsets.mergeAttrsList [
                        {
                          address = ":${toString value.port}";
                        }
                        value
                        {
                          port = null;
                        }
                      ]
                  )
                  config.dienilles.services.traefik.entrypoints
              );
          api = {
            dashboard = true;
          };
        };
      };

    system.stateVersion = "23.11";
  };
}