{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "bun";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    openssl
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    installShellFiles
    unzip
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bun-linux-x64/bun "$out/bin/bun"
    ln -s bun "$out/bin/bunx"

    runHook postInstall
  '';

  postPhases = [ "postPatchelf" ];

  postPatchelf = ''
    installShellCompletion --cmd bun \
      --bash <(SHELL="bash" $out/bin/bun completions) \
      --zsh <(SHELL="zsh" $out/bin/bun completions) \
      --fish <(SHELL="fish" $out/bin/bun completions)
  '';
}
