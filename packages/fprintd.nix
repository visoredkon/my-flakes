{
  libfprint,
  optimization,
  pkgs,
  ...
}:

(optimization.llvmStdenvWithArgs { inherit libfprint; } pkgs.fprintd).overrideAttrs
  optimization.withMesonClangMold
