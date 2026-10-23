{
  optimization,
  pkgs,
  extraPackages ? [ ],
}:

pkgs.yazi.override {
  inherit extraPackages;
  yazi-unwrapped = pkgs.yazi-unwrapped.overrideAttrs optimization.withRustOptimizations;
}
