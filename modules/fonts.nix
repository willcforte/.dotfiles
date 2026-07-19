{ pkgs, inputs, ... }:
let
  berkeley-mono = pkgs.stdenvNoCC.mkDerivation {
    pname = "berkeley-mono";
    version = "2.004";
    src = inputs.dotfiles-private;
    installPhase = ''
      runHook preInstall
      install -Dm644 fonts/BerkeleyMonoVariable.ttf -t $out/share/fonts/truetype
      runHook postInstall
    '';
    meta.description = "Berkeley Mono Variable";
  };

  # SF Pro is proprietary (Apple) and not in nixpkgs; build from the upstream
  # repo of .otf/.ttf files. Bump rev+hash with nix-prefetch-github.
  sf-pro-fonts = pkgs.stdenvNoCC.mkDerivation {
    pname = "sf-pro-fonts";
    version = "0-unstable-8bfea09";
    src = pkgs.fetchFromGitHub {
      owner = "sahibjotsaggu";
      repo = "San-Francisco-Pro-Fonts";
      rev = "8bfea09aa6f1139479f80358b2e1e5c6dc991a58";
      hash = "sha256-mAXExj8n8gFHq19HfGy4UOJYKVGPYgarGd/04kUIqX4=";
    };
    installPhase = ''
      runHook preInstall
      install -Dm644 *.otf -t $out/share/fonts/opentype
      install -Dm644 *.ttf -t $out/share/fonts/truetype
      runHook postInstall
    '';
    meta.description = "San Francisco Pro fonts, packaged from sahibjotsaggu/San-Francisco-Pro-Fonts";
  };
in {
  home.packages = [
    sf-pro-fonts                                    # SF Pro Display / Text (GNOME)
    berkeley-mono                                   # Berkeley Mono Variable (wezterm)
    pkgs.nerd-fonts.iosevka                         # "Iosevka Nerd Font" (VSCode)
    (pkgs.iosevka-bin.override { variant = "SGr-IosevkaTermSS18"; })  # IosevkaTerm SS18 (GNOME mono)
  ];

  # Make fontconfig see fonts from home.packages on non-NixOS.
  fonts.fontconfig.enable = true;
}
