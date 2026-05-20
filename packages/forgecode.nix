{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "forgecode";
  inherit release urlTemplate;

  dontBuild = true;
  dontUnpack = true;

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/forgecode"

    runHook postInstall
  '';
}
