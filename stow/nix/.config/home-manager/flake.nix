{
  description = "Home manager config for Ubuntu.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    claude-code-nix.url = "github:sadjow/claude-code-nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, claude-code-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations = {
        "will" = home-manager.lib.homeManagerConfiguration {
	  inherit pkgs;

	  modules = [
	    ./home.nix
	    { home.packages = [ claude-code-nix.packages.${system}.claude-code ]; }
	  ];
	};
      };
    };
}
