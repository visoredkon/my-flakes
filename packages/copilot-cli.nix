{
  autoPatchelfHook,
  fetchurl,
  gcc-unwrapped,
  release,
  stdenvNoCC,
  urlTemplate,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "copilot-cli";
  version = release.version;

  src = fetchurl {
    sha256 = release.sha256;
    url = builtins.replaceStrings [ "{version}" ] [ finalAttrs.version ] urlTemplate;
  };

  sourceRoot = ".";

  buildInputs = [
    gcc-unwrapped.lib
  ];

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  dontBuild = true;
  dontStrip = true;
  strictDeps = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 copilot "$out/bin/copilot"

    runHook postInstall
  '';
})
