{
  hyprlang,
  hyprutils,
  pkgs,
  ...
}:

pkgs.hyprpolkitagent.override {
  hyprland-qt-support = pkgs.hyprland-qt-support.override { inherit hyprlang; };
  inherit hyprutils;
}
