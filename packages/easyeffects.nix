{
  optimization,
  pkgs,
}:

pkgs.easyeffects.overrideAttrs optimization.withCMakeClangMold
