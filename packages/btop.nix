{
  optimization,
  pkgs,
}:

pkgs.btop.overrideAttrs optimization.moldEnv
