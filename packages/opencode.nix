{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "opencode";
  inherit release urlTemplate;

  dontBuild = true;

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 opencode "$out/bin/opencode"

    runHook postInstall
  '';

  sourceRoot = ".";
}
