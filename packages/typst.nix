{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "typst";
  inherit release urlTemplate;

  dontBuild = true;

  nativeBuildInputs = with pkgs; [
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 typst "$out/bin/typst"

    runHook postInstall
  '';

  postFixup = ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd typst --"$shell" <($out/bin/typst completions "$shell")
    done
  '';

  sourceRoot = "typst-x86_64-unknown-linux-musl";
}
