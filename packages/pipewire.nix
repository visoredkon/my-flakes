{
  optimization,
  pkgs,
}:

pkgs.pipewire.overrideAttrs optimization.withMesonClangMold
