{
  description = "Will's Nix config for Ubuntu 24 LTS dev.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-system-graphics = {
      url = "github:soupglasses/nix-system-graphics";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    solaar = {
      url = "github:Svenum/Solaar-Flake/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, claude-code-nix, system-manager, solaar, nix-system-graphics, nix-vscode-extensions, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ nix-vscode-extensions.overlays.default ];
      };

      # Flake-sourced packages. GL drivers come from /run/opengl-driver
      # (nix-system-graphics), so no nixGL wrapping is needed.
      flakePkgs = { home.packages = [
        claude-code-nix.packages.${system}.claude-code
      ]; };

      # Base config plus host-specific modules (will@<hostname>) where applicable.
      mkHome = modules: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs; };
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
