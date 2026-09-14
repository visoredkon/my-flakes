{
  optimization,
  pkgs,
}:

pkgs.libinput.overrideAttrs optimization.withMesonClangMold
