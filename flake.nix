{
  description = "Teefax NixOS config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # NOTE: change channel in gitlab runner when updating this

    disko.url = "github:nix-community/disko";

    nix-tun = {
      url = "github:nix-tun/nixos-modules";
      inputs.nixpkgs.follows = "nixpkgs"; # uses unstable internally
    };

    sops = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    authentik-nix = {
      url = "github:nix-community/authentik-nix";
      inputs.nixpkgs.follows = "nixpkgs"; # uses unstable internally
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      colmena,
      sops,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      lib = nixpkgs.lib.extend (
        final: prev: {
          dienilles = import ./lib.nix { lib = prev; };
        }
      );

      eachSystem = f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      specialArgs = {
        inherit inputs outputs lib;
      };
    in
    {
      formatter = eachSystem (_: pkgs: pkgs.nixfmt-tree);

      nixosModules.dienilles = import ./mod/nixos;

      colmenaHive = colmena.lib.makeHive self.outputs.colmena;
      colmena = {
        meta = {
          nixpkgs = import nixpkgs { system = "x86_64-linux"; };
          inherit specialArgs;
        };

        defaults.deployment = {
          buildOnTarget = true;
          targetUser = null;
        };

        dienilles = {
          deployment.targetHost = "dienilles.de";
          imports = [ ./nixos/dienilles ];
        };
      };

      nixosConfigurations.dienilles = lib.nixosSystem {
        inherit specialArgs;
        modules = [ ./nixos/dienilles ];
      };

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            sopsPGPKeyDirs = [
              "${toString ./.}/nixos/keys/hosts"
              "${toString ./.}/nixos/keys/users"
            ];

            nativeBuildInputs = [
              sops.packages.${system}.sops-import-keys-hook
              colmena.packages.${system}.colmena
            ];
          };
        }
      );
    };
}
