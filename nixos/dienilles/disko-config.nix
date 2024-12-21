{ lib, ... }:
{
  disko.devices = {
    disk.disk1 = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "256M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # Override existing partition
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                };
                "/persist" = {
                  mountpoint = "/persist";
                };
                "/nix" = {
                  mountOptions = [ "noatime" ];
                  mountpoint = "/nix";
                };
              };
              mountpoint = "/partition-root";
            };
          };
        };
      };
    };
  };
}
