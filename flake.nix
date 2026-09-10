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

          services.getty.autologinUser = "root";
          users.users.root.initialPassword = "root";

          system.stateVersion = "25.05";

          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          hardware.graphics.enable = lib.mkForce false;

          services.xserver = {
            enable = true;
            videoDrivers = [ "modesetting" ];
            windowManager.dwm.enable = true;
            displayManager.startx.enable = true;
          };
          services.pipewire.enable = lib.mkForce false;

          programs.bash.loginShellInit = ''
            if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
              exec startx ${pkgs.dwm}/bin/dwm
            fi
          '';

          environment.systemPackages = with pkgs; [
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
