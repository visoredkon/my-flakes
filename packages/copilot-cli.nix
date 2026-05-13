{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "copilot-cli";
  inherit release urlTemplate;

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 copilot "$out/bin/copilot"

    runHook postInstall
  '';

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  sourceRoot = ".";
}
