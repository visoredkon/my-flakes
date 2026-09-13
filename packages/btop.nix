{
  optimization,
  pkgs,
}:

pkgs.btop.overrideAttrs optimization.withCMakeClangMold
