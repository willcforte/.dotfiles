{
  description = "Will's Nix config for Ubuntu 24 LTS dev.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # nixGL bridges OpenGL for Nix GUI apps on non-NixOS (Ubuntu has no
    # /run/opengl-driver/lib, so the apps crash on libEGL). Uses its own
    # nixpkgs for a known-good Mesa, matching the build confirmed working.
    nixgl.url = "github:nix-community/nixGL";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, claude-code-nix, zen-browser, nixgl, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # obsidian, slack, vscode
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
    };
}
