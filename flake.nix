{
  description = "Will's Nix config for Ubuntu 24 LTS dev.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    solaar = {
      url = "github:Svenum/Solaar-Flake/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # System-wide OpenGL drivers on non-NixOS: populates /run/opengl-driver
    # via system-manager, so Nix GUI apps need no nixGL wrapping.
    nix-system-graphics = {
      url = "github:soupglasses/nix-system-graphics";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

  outputs = { nixpkgs, home-manager, claude-code-nix, zen-browser, system-manager, solaar, nix-system-graphics, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Flake-sourced packages. GL drivers come from /run/opengl-driver
      # (nix-system-graphics), so no nixGL wrapping is needed.
      flakePkgs = { home.packages = [
        claude-code-nix.packages.${system}.claude-code
        zen-browser.packages.${system}.default
      ]; };

      # Base config plus host-specific modules (will@<hostname>) where applicable.
      mkHome = modules: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix flakePkgs ] ++ modules;
      };
    in {
      homeConfigurations = {
        "will" = mkHome [ ];
        "will@will-pc14250" = mkHome [ ./hosts/will-pc14250.nix ];
        "will@persona-0020" = mkHome [ ./hosts/persona-0020.nix ];
      };

      # System-manager config (numtide/system-manager)
      systemConfigs.default = system-manager.lib.makeSystemConfig {
        modules = [
          nix-system-graphics.systemModules.default
          ./system.nix
        ];
      };
    };
}
