{ ... }:
{
  imports = [
    ./authentik
    ./openssh.nix
    ./prometheus
    ./vaultwarden
    ./ntfy
    ./traefik.nix
    ./node_exporter
  ];
}
