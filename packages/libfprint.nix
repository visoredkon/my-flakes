{
  optimization,
  pkgs,
  release,
  ...
}:

(optimization.llvmStdenv pkgs.libfprint).overrideAttrs (
  old:
  {
    src = pkgs.fetchFromGitHub {
      owner = "visoredkon";
      repo = "libfprint-egis0576";
      inherit (release) rev;
      hash = release.sourceSha256;
    };
  }
  // optimization.withMesonClangMold old
)
