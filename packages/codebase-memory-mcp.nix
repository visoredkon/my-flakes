{
  autoPatchelfHook,
  gcc-unwrapped,
  mkPrebuilt,
  release,
  urlTemplate,
  zlib,
}:

mkPrebuilt {
  pname = "codebase-memory-mcp";
  inherit release urlTemplate;

  buildInputs = [
    gcc-unwrapped
    zlib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 codebase-memory-mcp "$out/bin/codebase-memory-mcp"

    runHook postInstall
  '';

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  sourceRoot = ".";
}
