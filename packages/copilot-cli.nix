{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "copilot-cli";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 copilot "$out/bin/copilot"

    runHook postInstall
  '';
}
