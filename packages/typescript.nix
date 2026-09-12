{
  lib,
  optimization,
  pkgs,
  release,
  ...
}:

optimization.withGoOptimizations {
  goBuilder = pkgs.buildGo126Module;
  pname = "typescript";
  inherit (release) vendorHash version;

  src = pkgs.fetchFromGitHub {
    owner = "microsoft";
    repo = "TypeScript";
    tag = "v${release.version}";
    hash = release.sourceSha256;
  };

  modRoot = "tsc";

  tags = [
    "noembed"
  ];

  subPackages = [
    "cmd/tsgo"
  ];

  nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];

  env.CGO_ENABLED = 0;

  postInstall = ''
    lib_dir="$out/lib/typescript"
    mkdir -p "$lib_dir"
    cp -r internal/bundled/libs/. "$lib_dir"

    mv "$out/bin/tsgo" "$lib_dir/tsc"

    ln -s "$lib_dir/tsc" "$out/bin/tsc"
    ln -s "$lib_dir/tsc" "$out/bin/tsgo"
  '';

  meta = {
    description = "Superset of JavaScript that compiles to clean JavaScript output";
    homepage = "https://www.typescriptlang.org/";
    changelog = "https://github.com/microsoft/TypeScript/releases/tag/v${release.version}";
    license = lib.licenses.asl20;
    mainProgram = "tsc";
  };
}
