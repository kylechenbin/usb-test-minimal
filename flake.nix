{
  description = "Gaming target config for usb-bootstrap (generic + nvidia profiles)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs, ... }:
    let
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
          memoryPercent = 100;
          priority = 999;
          algorithm = "zstd";
        };

        nix.settings = {
          auto-optimise-store = false;   # 一次性 tmpfs 系统用不上，省下这份开销
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

        services.xserver.windowManager.dwm.enable = true;
        services.xserver.displayManager.startx.enable = true;

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
        security.rtkit.enable = true;   # 新加，pipewire 需要

        services.udisks2.enable = true;
        security.polkit.enable = true;

        programs.bash.loginShellInit = ''
          if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
            exec startx ${pkgs.writeShellScript "start-session" ''
              ${pkgs.udiskie}/bin/udiskie &
              exec ${pkgs.dwm}/bin/dwm
            ''}
          fi
        '';

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
    in
    {
      # 通用兜底：AMD / Intel / 未知或旧款 Nvidia
      nixosConfigurations.usb-test = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          commonModule
          {
            networking.hostName = "usb-test-target";
            services.xserver.enable = true;
            services.xserver.videoDrivers = [ "modesetting" "amdgpu" "nouveau" ];
          }
        ];
      };

      # 已知是较新 Nvidia 独显(RTX 20系+)时用这个
      nixosConfigurations.usb-test-nvidia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          commonModule
          ({ config, ... }: {
            networking.hostName = "usb-test-nvidia";
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
    };
}
