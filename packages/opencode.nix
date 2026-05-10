{
  autoPatchelfHook,
  mkPrebuilt,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "opencode";
  inherit release urlTemplate;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 opencode "$out/bin/opencode"

    runHook postInstall
  '';

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  sourceRoot = ".";
}
