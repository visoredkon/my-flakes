{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "codebase-memory-mcp";
  inherit release urlTemplate;

  buildInputs = with pkgs; [
    gcc-unwrapped
    zlib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 codebase-memory-mcp "$out/bin/codebase-memory-mcp"

    runHook postInstall
  '';

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  sourceRoot = ".";
}
