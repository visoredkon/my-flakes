{
  aquamarine,
  hyprgraphics,
  hyprlang,
  hyprtoolkit,
  hyprutils,
  pkgs,
  ...
}:

pkgs.hyprpolkitagent.override {
  inherit
    aquamarine
    hyprgraphics
    hyprlang
    hyprtoolkit
    hyprutils
    ;
}
