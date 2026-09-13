{
  description = "Gaming target config for usb-bootstrap (generic + nvidia + dwl profiles)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs, ... }:
    let
      # ---- 真正跟窗口系统无关的公共部分 ----
      commonModule = { pkgs, lib, ... }: {
        networking.useDHCP = lib.mkForce false;
        networking.networkmanager.enable = true;

        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
        boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];

        boot.kernel.sysctl = {
          "vm.swappiness" = 180;
          "vm.watermark_boost_factor" = 0;
          "vm.watermark_scale_factor" = 125;
          "vm.page-cluster" = 0;
        };

        zramSwap = {
          enable = true;
          memoryPercent = 80;
          priority = 999;
          algorithm = "zstd";
        };

        nix.settings = {
          auto-optimise-store = false;
          max-jobs = "auto";
          experimental-features = [ "nix-command" "flakes" ];
        };
        nix.gc = {
          automatic = true;
          dates = "daily";
          options = "--delete-older-than 1d";
        };

        services.journald.extraConfig = ''
          SystemMaxUse=50M
          RuntimeMaxUse=50M
        '';

        services.getty.autologinUser = "test";
        users.users.root.initialPassword = "root";
        users.users.test = {
          isNormalUser = true;
          initialPassword = "test";
          extraGroups = [ "wheel" ];
          packages = with pkgs; [ tree ];
        };

        system.stateVersion = "25.05";

        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };

        programs.gamemode.enable = true;

        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
        security.rtkit.enable = true;

        services.udisks2.enable = true;
        security.polkit.enable = true;

        environment.systemPackages = with pkgs; [
          pamixer
          vifm
          udiskie
          umu-launcher
          vim
          qutebrowser
          btop
          dmenu
          st
        ];
      };

      # ---- X11 + dwm 专属部分 ----
      x11Module = { pkgs, ... }: {
        services.xserver.windowManager.dwm.enable = true;
        services.xserver.displayManager.startx.enable = true;

        programs.bash.loginShellInit = ''
          if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
            exec startx ${pkgs.writeShellScript "start-session" ''
              ${pkgs.udiskie}/bin/udiskie &
              exec ${pkgs.dwm}/bin/dwm
            ''}
          fi
        '';
      };

      # ---- Wayland + dwl 专属部分 ----
      waylandModule = { pkgs, ... }: {
        # dwl 场景不需要 X server
        services.xserver.enable = false;

        # 让非 root 用户能拿到 seat/DRM 权限
        services.seatd.enable = true;
        users.users.test.extraGroups = [ "video" "render" "seat" ];

        environment.systemPackages = [ pkgs.dwl pkgs.foot ];  # foot: 一个轻量 wayland 终端，替代 st

        programs.bash.loginShellInit = ''
          if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
            exec dbus-run-session ${pkgs.writeShellScript "start-dwl-session" ''
              export XDG_RUNTIME_DIR="/run/user/$(id -u)"
              mkdir -p "$XDG_RUNTIME_DIR"
              ${pkgs.udiskie}/bin/udiskie --no-automount &
              exec ${pkgs.dwl}/bin/dwl
            ''}
          fi
        '';
      };
    in
    {
      # AMD / Intel / 未知或旧款 Nvidia，X11 + dwm
      nixosConfigurations.usb-test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          commonModule
          x11Module
          {
            networking.hostName = "usb-test-target";
            services.xserver.enable = true;
            services.xserver.videoDrivers = [ "modesetting" "amdgpu" "nouveau" ];
          }
        ];
      };

      # 较新 Nvidia 独显(RTX 20系+)，X11 + dwm
      nixosConfigurations.usb-test-nvidia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          commonModule
          x11Module
          ({ config, ... }: {
            networking.hostName = "usb-test-nvidia";
            nixpkgs.config.allowUnfree = true;
            services.xserver.enable = true;
            services.xserver.videoDrivers = [ "nvidia" ];
            hardware.nvidia = {
              modesetting.enable = true;
              open = true;
              package = config.boot.kernelPackages.nvidiaPackages.stable;
            };
          })
        ];
      };

      # 较老 Nvidia 独显(GTX 600-900系一带)，X11 + dwm
      nixosConfigurations.usb-test-nvidia-legacy = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          commonModule
          x11Module
          ({ config, ... }: {
            networking.hostName = "usb-test-nvidia-legacy";
            nixpkgs.config.allowUnfree = true;
            services.xserver.enable = true;
            services.xserver.videoDrivers = [ "nvidia" ];
            hardware.nvidia = {
              modesetting.enable = true;
              open = false;
              package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
            };
          })
        ];
      };

      # AMD / Intel / 较新 Nvidia，Wayland + dwl（实验性，旧款 Nvidia 不建议用这个）
      nixosConfigurations.usb-test-dwl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          commonModule
          waylandModule
          {
            networking.hostName = "usb-test-dwl";
          }
        ];
      };
    };
}
