{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.swappy).overrideAttrs optimization.withMesonClangMold
