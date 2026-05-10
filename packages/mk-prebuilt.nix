{
  fetchurl,
  stdenvNoCC,
}:

{
  pname,
  release,
  urlTemplate,
  ...
}@args:

stdenvNoCC.mkDerivation (
  (removeAttrs args [
    "pname"
    "release"
    "urlTemplate"
  ])
  // {
    inherit pname;

    dontStrip = true;

    src = fetchurl {
      sha256 = release.sha256;
      url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
    };

    strictDeps = true;
    version = release.version;
  }
)
