{
  description = "Teefax NixOS config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # NOTE: change channel in gitlab runner when updating this
    nixpkgs-master.url = "github:nixos/nixpkgs";

    disko.url = "github:nix-community/disko";

    nix-tun = {
      url = "github:nix-tun/nixos-modules";
      inputs.nixpkgs.follows = "nixpkgs"; # uses unstable internally
    };

    sops = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-programs-sqlite = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    authentik-nix = {
      url = "github:nix-community/authentik-nix";
      inputs.nixpkgs.follows = "nixpkgs"; # uses unstable internally
    };
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-master
    , ...
    }@inputs:
    let
      inherit (self) outputs;
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      lib = nixpkgs.lib;

      forAllSystems = lib.genAttrs systems;
    in
    {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      overlays = import ./overlays.nix { inherit inputs; };

      nixosModules.dienilles = import ./mod/nixos;

      nixosConfigurations.dienilles = lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          pkgs-master = import nixpkgs-master {
            system = "x86_64-linux";
          };
        };
        modules = [ ./nixos/dienilles ];
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            sopsPGPKeyDirs = [
              "${toString ./.}/nixos/keys/hosts"
              "${toString ./.}/nixos/keys/users"
            ];

            nativeBuildInputs = with pkgs; [
              (callPackage inputs.sops { }).sops-import-keys-hook
              nixos-rebuild
            ];
          };
        }
      );
    };
}

