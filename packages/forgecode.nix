{
  autoPatchelfHook,
  fetchurl,
  gcc-unwrapped,
  release,
  stdenvNoCC,
  urlTemplate,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "forgecode";
  version = release.version;

  src = fetchurl {
    sha256 = release.sha256;
    url = builtins.replaceStrings [ "{version}" ] [ finalAttrs.version ] urlTemplate;
  };

  buildInputs = [
    gcc-unwrapped.lib
  ];

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  dontBuild = true;
  dontStrip = true;
  dontUnpack = true;
  strictDeps = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/forgecode"

    runHook postInstall
  '';
})
