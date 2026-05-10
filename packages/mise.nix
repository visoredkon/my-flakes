{
  autoPatchelfHook,
  gcc-unwrapped,
  mkPrebuilt,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "mise";
  inherit release urlTemplate;

  buildInputs = [
    gcc-unwrapped.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 mise/bin/mise "$out/bin/mise"

    runHook postInstall
  '';

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  sourceRoot = ".";
}
