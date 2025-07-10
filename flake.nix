{
  description = "Nix flake for retiolum VPN";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
    }:
    {
      nixosModules.retiolum = ./modules/retiolum;
      nixosModules.ca = ./modules/ca;
      darwinModules.tinc = ./darwin/tinc.nix;
      darwinModules.retiolum = ./darwin/retiolum.nix;

      # Example Darwin configuration for testing
      darwinConfigurations.example = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          self.darwinModules.tinc
          self.darwinModules.retiolum
          (
            { pkgs, ... }:
            {
              # Basic nix-darwin configuration
              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];

              # Enable retiolum
              networking.retiolum = {
                nodename = "example";
                ipv4 = "10.243.99.99";
                ipv6 = "42:0:3c46:dead:beef:dead:beef:dead";
              };

              # Required for nix-darwin
              system.stateVersion = 4;
            }
          )
        ];
      };

      # Example NixOS configuration for testing
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.retiolum
          (
            { pkgs, ... }:
            {
              # Basic NixOS configuration
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "tmpfs";
                fsType = "tmpfs";
              };

              # Enable retiolum
              networking.retiolum = {
                nodename = "example";
                ipv4 = "10.243.99.99";
                ipv6 = "42:0:3c46:dead:beef:dead:beef:dead";
              };

              # Required for NixOS
              system.stateVersion = "23.11";
            }
          )
        ];
      };
    };
}
