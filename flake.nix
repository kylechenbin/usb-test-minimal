{
  description = "Minimal target config for usb-bootstrap testing";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  {
    nixosConfigurations.usb-test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, lib, ... }: {
          # 沿用 live 环境本身的关键设置，避免 rebuild 后网络/引导炸掉
          networking.hostName = "usb-test-target";
          networking.useDHCP = lib.mkForce true;

          boot.loader.grub.enable = false;
          fileSystems."/" = { device = "none"; fsType = "tmpfs"; };

          services.getty.autologinUser = "root";
          users.users.root.initialPassword = "root";

          system.stateVersion = "24.05";

          environment.systemPackages = [ pkgs.htop ];
        })
      ];
    };
  };
}
