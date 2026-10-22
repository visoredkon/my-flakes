{
  optimization,
  pkgs,
  ...
}:

pkgs.fastfetch.override {
  fastfetch-unwrapped = pkgs.fastfetch-unwrapped.overrideAttrs optimization.withCMakeClangMold;
}
