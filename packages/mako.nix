{
  optimization,
  pkgs,
}:

pkgs.mako.overrideAttrs optimization.withMesonClangMold
