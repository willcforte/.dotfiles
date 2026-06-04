{
  description = "Will's Nix config for Ubuntu 24 LTS dev.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, claude-code-nix, zen-browser, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # obsidian, slack, vscode
      };

      flakePkgs = { home.packages = [
        claude-code-nix.packages.${system}.claude-code
        zen-browser.packages.${system}.default
      ]; };

      # Base config plus optional host-specific modules.
      # `home-manager switch` picks "will@<hostname>" when it exists,
      # falling back to plain "will" on hosts without their own module.
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
    };
}
