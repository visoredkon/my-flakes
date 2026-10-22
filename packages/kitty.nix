{
  optimization,
  pkgs,
  ...
}:

(optimization.llvmStdenv pkgs.kitty).overrideAttrs optimization.withGoOverride
