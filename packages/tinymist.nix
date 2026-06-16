{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

assert release ? completionsSha256 && release.completionsSha256 != "";

let
  completionsArchive = pkgs.fetchurl {
    sha256 = release.completionsSha256;
    url = "https://github.com/Myriad-Dreamin/tinymist/releases/download/v${release.version}/tinymist-completions.tar.gz";
  };
in
mkPrebuilt {
  pname = "tinymist";
  inherit release urlTemplate;

  dontBuild = true;

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
    glibc
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tinymist "$out/bin/tinymist"

    runHook postInstall
  '';

  postFixup = ''
    mkdir -p completions

    tar --extract --file "${completionsArchive}" --directory completions --strip-components=1 \
      "completions/bash/tinymist" \
      "completions/fish/vendor_completions.d/tinymist.fish" \
      "completions/zsh/_tinymist"

    installShellCompletion \
      --bash completions/bash/tinymist \
      --fish completions/fish/vendor_completions.d/tinymist.fish \
      --zsh completions/zsh/_tinymist
  '';

  sourceRoot = "tinymist-x86_64-unknown-linux-gnu";
}
