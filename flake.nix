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
          services.udisks2.enable = true;
          programs.bash.loginShellInit = ''
            if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
              exec startx ${pkgs.writeShellScript "start-session" ''
                # Start udiskie with a tray icon or in the background
                ${pkgs.udiskie}/bin/udiskie --tray &

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
