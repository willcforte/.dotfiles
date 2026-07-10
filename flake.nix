{
  description = "Will's Nix config for Ubuntu 24 LTS dev.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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

    # System-wide OpenGL drivers on non-NixOS: populates /run/opengl-driver
    # via system-manager, so Nix GUI apps need no nixGL wrapping.
    nix-system-graphics = {
      url = "github:soupglasses/nix-system-graphics";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Full VS Code marketplace (incl. MS-proprietary) as Nix packages, so
    # extensions are declarative. Provides the vscode-marketplace overlay.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
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

    # macOS system config (this Mac's analogue of system-manager on Linux).
    # Pinned to a commit contemporaneous with the nixpkgs pin: nix-darwin master
    # later started passing `--sidebar-depth` to nixos-render-docs, which our
    # (older) pinned nixpkgs can't parse, breaking the whole system build. Bump
    # this together with nixpkgs.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/f8531f95fe4abebe17b794f3f6c01a8f886b97bd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, claude-code-nix, system-manager, solaar, nix-system-graphics, nix-vscode-extensions, nix-darwin, ... }:
    let
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ nix-vscode-extensions.overlays.default ];
      };

      # Flake-sourced packages. GL drivers come from /run/opengl-driver
      # (nix-system-graphics), so no nixGL wrapping is needed on Linux.
      flakePkgsFor = system: { home.packages = [
        claude-code-nix.packages.${system}.claude-code
      ]; };

      # Base config plus host-specific modules (will@<hostname>) where applicable.
      # isDarwin is passed as a specialArg (available before `pkgs` is, unlike
      # pkgs.stdenv.isDarwin) so home.nix can safely use it inside `imports`.
      mkHomeFor = system: modules: home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor system;
        extraSpecialArgs = {
          inherit inputs;
          isDarwin = builtins.match ".*-darwin" system != null;
        };
        modules = [ ./home.nix (flakePkgsFor system) ] ++ modules;
      };
      mkHome = mkHomeFor "x86_64-linux";
    in {
      homeConfigurations = {
        "will" = mkHome [ ];
        "will@will-pc14250" = mkHome [ ./hosts/will-pc14250.nix ];
        "will@persona-0020" = mkHome [ ./hosts/persona-0020.nix ];
        "will@will-mbp" = mkHomeFor "aarch64-darwin" [ ./hosts/will-mbp.nix ];
      };

      # System-manager config (numtide/system-manager) — Linux boxes only.
      systemConfigs.default = system-manager.lib.makeSystemConfig {
        modules = [
          nix-system-graphics.systemModules.default
          ./system.nix
        ];
      };

      # nix-darwin system config — this Mac's analogue of systemConfigs.default.
      darwinConfigurations."will-mbp" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [ ./darwin/system.nix ];
      };
    };
}
