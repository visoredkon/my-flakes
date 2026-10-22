{
  optimization,
  pkgs,
  wl-clipboard,
  ...
}:

(optimization.llvmStdenvWithArgs { inherit wl-clipboard; } pkgs.espanso-wayland).overrideAttrs
  optimization.withRustOptimizations
