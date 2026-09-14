{
  grim,
  libinput,
  optimization,
  pipewire,
  pkgs,
  slurp,
}:

let
  llvmStdenv = pkgs.llvmPackages.stdenv;
  fullLto = optimization.withCMakeClangMold;
  thinLto = optimization.withCMakeClangMoldMode "thin";

  llvmOptimized =
    optimizer: name: deps:
    (pkgs.${name}.override ({ gcc16Stdenv = llvmStdenv; } // deps)).overrideAttrs optimizer;

  hyprutils = llvmOptimized fullLto "hyprutils" { };

  hyprlang = llvmOptimized fullLto "hyprlang" { inherit hyprutils; };

  hyprcursor = llvmOptimized fullLto "hyprcursor" { inherit hyprlang; };

  hyprgraphics = llvmOptimized fullLto "hyprgraphics" { inherit hyprutils; };

  aquamarine = llvmOptimized fullLto "aquamarine" { };

  hyprtoolkit = llvmOptimized thinLto "hyprtoolkit" {
    inherit
      aquamarine
      hyprgraphics
      hyprlang
      hyprutils
      ;
  };

  hyprwire = llvmOptimized thinLto "hyprwire" { inherit hyprutils; };

  hyprland =
    (pkgs.hyprland.override {
      inherit
        aquamarine
        hyprcursor
        hyprgraphics
        hyprlang
        hyprutils
        libinput
        ;
    }).overrideAttrs
      fullLto;

  hypridle = llvmOptimized thinLto "hypridle" { inherit hyprlang hyprutils; };

  hyprlock = llvmOptimized thinLto "hyprlock" { inherit hyprgraphics hyprlang hyprutils; };

  hyprpaper = llvmOptimized thinLto "hyprpaper" {
    inherit
      aquamarine
      hyprgraphics
      hyprlang
      hyprtoolkit
      hyprutils
      hyprwire
      ;
  };

  xdgDesktopPortalHyprland =
    (pkgs.xdg-desktop-portal-hyprland.override {
      stdenv = llvmStdenv;
      inherit
        grim
        hyprland
        hyprlang
        hyprutils
        pipewire
        slurp
        ;
    }).overrideAttrs
      thinLto;
in
{
  inherit
    aquamarine
    hyprcursor
    hyprgraphics
    hypridle
    hyprland
    hyprlang
    hyprlock
    hyprpaper
    hyprtoolkit
    hyprutils
    hyprwire
    ;
  xdg-desktop-portal-hyprland = xdgDesktopPortalHyprland;
}
