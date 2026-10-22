{
  optimization,
  pkgs,
}:

(optimization.llvmStdenv pkgs.mako).overrideAttrs optimization.withMesonClangMold
