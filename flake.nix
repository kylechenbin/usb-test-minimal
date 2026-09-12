{
  description = "Minimal target config for usb-bootstrap testing";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  outputs = { self, nixpkgs, ... }:
  {
    nixosConfigurations.usb-test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, lib, ... }: {
          networking.hostName = "usb-test-target";
          networking.useDHCP = lib.mkForce true;
          networking.networkmanager.enable = true;

          boot.loader.grub.enable = false;
          fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
          boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];

          services.getty.autologinUser = "test";
          users.users.root.initialPassword = "root";
          users.users.test.initialPassword = "test";

          system.stateVersion = "25.05";

          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          services.xserver = {
            enable = true;
            videoDrivers = [ "modesetting" "amdgpu" "nouveau" ];
            windowManager.dwm.enable = true;
            displayManager.startx.enable = true;
          };

          hardware.graphics = {
            enable = true;
            enable32Bit = true;   # Steam/大部分游戏依赖 32 位库
          };

          # gamescope/gamemode 这类优化工具,可选
          programs.gamemode.enable = true;

          services.pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;   # 32 位游戏需要，跟 hardware.graphics.enable32Bit 配套
            pulse.enable = true;        # 大部分游戏走 PulseAudio 兼容层跟音频交互
          };

          services.udisks2.enable = true;
          programs.bash.loginShellInit = ''
            if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
              exec startx ${pkgs.writeShellScript "start-session" ''
                ${pkgs.udiskie}/bin/udiskie &
                exec ${pkgs.dwm}/bin/dwm
              ''}
            fi
          '';

          # Define a user account. Don't forget to set a password with ‘passwd’.
          users.users.test = {
            isNormalUser = true;
            extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
            packages = with pkgs; [
              tree
            ];
          };

          security.polkit.enable = true;

          environment.systemPackages = with pkgs; [
            vifm
            udiskie
            umu-launcher
            vim
            firefox
            btop
            dmenu
            st
          ];
        })
      ];
    };
  };
}
