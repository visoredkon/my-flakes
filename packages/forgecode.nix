{
  autoPatchelfHook,
  gcc-unwrapped,
  mkPrebuilt,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "forgecode";
  inherit release urlTemplate;

  buildInputs = [
    gcc-unwrapped.lib
  ];

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/forgecode"

    runHook postInstall
  '';

  nativeBuildInputs = [
    autoPatchelfHook
  ];
}
