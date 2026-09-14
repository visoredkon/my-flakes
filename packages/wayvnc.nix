{
  optimization,
  pkgs,
}:

pkgs.wayvnc.overrideAttrs optimization.withMesonClangMold
