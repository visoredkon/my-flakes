{
  autoPatchelfHook,
  fetchurl,
  release,
  stdenvNoCC,
  urlTemplate,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gortex";
  version = release.version;

  src = fetchurl {
    sha256 = release.sha256;
    url = builtins.replaceStrings [ "{version}" ] [ finalAttrs.version ] urlTemplate;
  };

  sourceRoot = ".";

  dontBuild = true;
  dontStrip = true;
  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 gortex "$out/bin/gortex"

    runHook postInstall
  '';
})
