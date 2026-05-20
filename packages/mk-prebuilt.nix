{ pkgs }:

{
  pname,
  release,
  urlTemplate,
  ...
}@args:

assert pname != "";
assert release ? sha256 && release.sha256 != "";
assert release ? version && release.version != "";
assert urlTemplate != "";

pkgs.stdenvNoCC.mkDerivation (
  (removeAttrs args [
    "pname"
    "release"
    "urlTemplate"
  ])
  // {
    inherit pname;
    inherit (release) version;
    src = pkgs.fetchurl {
      inherit (release) sha256;
      url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
    };

    dontStrip = true;
    strictDeps = true;
  }
)
