{
  description = "Will's Nix config for Ubuntu 24 LTS dev.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, claude-code-nix, zen-browser, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations = {
        "will" = home-manager.lib.homeManagerConfiguration {
	  inherit pkgs;

	  modules = [
	    ./home.nix
	    { home.packages = [
	        claude-code-nix.packages.${system}.claude-code
	        zen-browser.packages.${system}.default
	      ]; }
	  ];
	};
      };
    };
}
