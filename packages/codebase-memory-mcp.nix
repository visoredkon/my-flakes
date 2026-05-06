{
  autoPatchelfHook,
  fetchurl,
  gcc-unwrapped,
  release,
  stdenvNoCC,
  urlTemplate,
  zlib,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codebase-memory-mcp";
  version = release.version;

  src = fetchurl {
    sha256 = release.sha256;
    url = builtins.replaceStrings [ "{version}" ] [ finalAttrs.version ] urlTemplate;
  };

  sourceRoot = ".";

  dontBuild = true;
  dontStrip = true;
  strictDeps = true;

  buildInputs = [
    gcc-unwrapped
    zlib
  ];

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 codebase-memory-mcp "$out/bin/codebase-memory-mcp"

    runHook postInstall
  '';
})
