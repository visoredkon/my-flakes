{ pkgs }:

{
  pname,
  release,
  urlTemplate,
  ...
}@args:

pkgs.stdenvNoCC.mkDerivation (
  (builtins.removeAttrs args [
    "pname"
    "release"
    "urlTemplate"
  ])
  // {
    inherit pname;

    dontStrip = true;

    src = pkgs.fetchurl {
      sha256 = release.sha256;
      url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
    };

    strictDeps = true;
    version = release.version;
  }
)
