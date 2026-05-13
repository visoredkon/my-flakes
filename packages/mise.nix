{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "mise";
  inherit release urlTemplate;

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 mise/bin/mise "$out/bin/mise"

    runHook postInstall
  '';

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  sourceRoot = ".";
}
