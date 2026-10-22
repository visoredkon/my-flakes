{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

let
  completionsArchive = pkgs.fetchurl {
    sha256 = release.completionsSha256;
    url = "https://github.com/Myriad-Dreamin/tinymist/releases/download/v${release.version}/tinymist-completions.tar.gz";
  };
in
mkPrebuilt {
  pname = "tinymist";
  inherit release urlTemplate;

  completions = {
    archive = completionsArchive;
    stripComponents = 1;
    prefix = "completions/";
    files = {
      bash = "bash/tinymist";
      fish = "fish/vendor_completions.d/tinymist.fish";
      zsh = "zsh/_tinymist";
    };
  };

  dontBuild = true;
  sourceRoot = "tinymist-x86_64-unknown-linux-gnu";

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
}
