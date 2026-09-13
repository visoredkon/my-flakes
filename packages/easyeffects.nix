{
  optimization,
  pkgs,
}:

pkgs.easyeffects.overrideAttrs optimization.withMesonClangMold
