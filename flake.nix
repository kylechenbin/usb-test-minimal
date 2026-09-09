{
  description = "Minimal target config for usb-bootstrap testing";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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

          services.getty.autologinUser = "root";
          users.users.root.initialPassword = "root";

          system.stateVersion = "25.05";

          # X + dwm
          services.xserver.enable = true;
          services.xserver.windowManager.dwm.enable = true;

          # 自动起图形界面:autologin 到 tty 后跑 startx
          services.xserver.displayManager.startx.enable = true;
          programs.bash.loginShellInit = ''
            if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
              startx
            fi
          '';

          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          environment.systemPackages = [
            pkgs.htop
            pkgs.btop
            pkgs.firefox
            pkgs.dmenu   # dwm 标配的启动器,没有它 dwm 里几乎啥也点不开
            pkgs.st      # suckless 的终端,dwm 默认按 Mod+Shift+Return 开的就是它
          ];
        })
      ];
    };
  };
}
