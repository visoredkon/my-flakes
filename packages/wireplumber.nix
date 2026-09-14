{
  optimization,
  pipewire,
  pkgs,
}:

(pkgs.wireplumber.override {
  inherit pipewire;
}).overrideAttrs
  optimization.withMesonClangMold
