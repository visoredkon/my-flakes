{
  optimization,
  pkgs,
  release,
  ...
}:

assert release ? rev && release.rev != "";
assert release ? sourceSha256 && release.sourceSha256 != "";

(pkgs.libfprint.override {
  stdenv = pkgs.llvmPackages.stdenv;
}).overrideAttrs
  (
    old:
    {
      src = pkgs.fetchFromGitHub {
        owner = "visoredkon";
        repo = "libfprint-egis0576";
        inherit (release) rev;
        hash = release.sourceSha256;
      };

      patches = [ ];
      doCheck = false;
    }
    // optimization.withMesonClangMold old
  )
