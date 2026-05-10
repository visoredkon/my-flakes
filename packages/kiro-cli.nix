{
  autoPatchelfHook,
  gcc-unwrapped,
  mkPrebuilt,
  release,
  unzip,
  urlTemplate,
}:

mkPrebuilt {
  pname = "kiro-cli";
  inherit release urlTemplate;

  buildInputs = [
    gcc-unwrapped.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -Dm755 kirocli/bin/kiro-cli "$out/bin/kiro-cli"
    install -Dm755 kirocli/bin/kiro-cli-chat "$out/bin/kiro-cli-chat"
    ln -s "$out/bin/kiro-cli" "$out/bin/q"

    runHook postInstall
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];

  unpackPhase = ''
    unzip $src
  '';
}
