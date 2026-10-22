{
  optimization,
  pkgs,
}:

pkgs.yazi.override {
  yazi-unwrapped = pkgs.yazi-unwrapped.overrideAttrs optimization.withRustOptimizations;
}
