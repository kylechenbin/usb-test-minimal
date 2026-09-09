{
  description = "Minimal target config for usb-bootstrap testing";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  {
    nixosConfigurations.usb-test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, lib, ... }: {
          networking.hostName = "usb-test-target";
          networking.useDHCP = lib.mkForce true;

          boot.loader.grub.enable = false;
          fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
          boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];

          services.getty.autologinUser = "root";
          users.users.root.initialPassword = "root";

          system.stateVersion = "25.05";

          # ↓ 从顶层挪到这里
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          # 关掉硬件加速,避免拉 mesa+llvm 撑爆 tmpfs
          hardware.graphics.enable = lib.mkForce false;

          services.xserver = {
            enable = true;
            videoDrivers = [ "vesa" ];
            windowManager.dwm.enable = true;
            displayManager.startx.enable = true;
          };
          services.pipewire.enable = lib.mkForce false;
          sound.enable = lib.mkForce false;

          programs.bash.loginShellInit = ''
            if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
              startx
            fi
          '';

          environment.systemPackages = [
            pkgs.htop
            pkgs.btop
            pkgs.dmenu
            pkgs.st
            # firefox 先去掉,内存紧张时几乎必炸;链路和 dwm 都跑通后再单独加回来测
          ];
        })
      ];
    };
  };
}
