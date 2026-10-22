{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.slurp).overrideAttrs optimization.withMesonClangMold
