{
  libfprint,
  optimization,
  pkgs,
  ...
}:

(pkgs.fprintd.override {
  stdenv = pkgs.llvmPackages.stdenv;
  inherit libfprint;
}).overrideAttrs
  optimization.withMesonClangMold
