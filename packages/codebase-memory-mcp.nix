{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "codebase-memory-mcp";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    gcc-unwrapped
    zlib
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 codebase-memory-mcp "$out/bin/codebase-memory-mcp"

    runHook postInstall
  '';
}
