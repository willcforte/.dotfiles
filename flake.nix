{
  description = "Will's Nix config for Ubuntu 24 LTS dev.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    nixgl.url = "github:nix-community/nixGL";

    # Declarative system-level config (/etc, systemd) on non-NixOS.
    # system-manager tracks nixos-unstable; safe to share our nixpkgs now
    # that we're on unstable too (its userborn module needs unstable).
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, claude-code-nix, zen-browser, nixgl, system-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # A module (takes config) so zen-browser can be nixGL-wrapped like the
      # other GUI apps — non-NixOS has no system GL, so the unwrapped browser
      # hits the same libEGL crash. claude-code is a CLI; left unwrapped.
      flakePkgs = { config, ... }: { home.packages = [
        claude-code-nix.packages.${system}.claude-code
        (config.lib.nixGL.wrap zen-browser.packages.${system}.default)
      ]; };

      # Base config plus optional host-specific modules.
      # `home-manager switch` picks "will@<hostname>" when it exists,
      # falling back to plain "will" on hosts without their own module.
      mkHome = modules: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        # nixgl is consumed by home.nix (nixGL.packages) to wrap GUI apps.
        extraSpecialArgs = { inherit nixgl; };
        modules = [ ./home.nix flakePkgs ] ++ modules;
      };
    in {
      homeConfigurations = {
        "will" = mkHome [ ];
        "will@will-pc14250" = mkHome [ ./hosts/will-pc14250.nix ];
        "will@persona-0020" = mkHome [ ./hosts/persona-0020.nix ];
      };

      # System-level config, activated separately from home-manager via
      # `nix run github:numtide/system-manager -- switch --flake . --sudo`
      # (wired into the update-config helper).
      systemConfigs.default = system-manager.lib.makeSystemConfig {
        modules = [ ./system.nix ];
      };
    };
}
