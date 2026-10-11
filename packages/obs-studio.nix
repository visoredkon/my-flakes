{
  optimization,
  pkgs,
}:

let
  obs-studio = (pkgs.obs-studio.override { stdenv = pkgs.llvmPackages.stdenv; }).overrideAttrs (
    old:
    let
      base = optimization.withCMakeClangMoldMode "none" old;
    in
    base
    // {
      cmakeFlags =
        builtins.filter (f: f != "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON") (base.cmakeFlags or [ ])
        ++ [ "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF" ];

      postPatch = (old.postPatch or "") + ''
        substituteInPlace plugins/obs-nvenc/CMakeLists.txt \
          --replace-fail "add_subdirectory(obs-nvenc-test)" ""
        substituteInPlace plugins/obs-x264/CMakeLists.txt \
          --replace-fail "include(cmake/x264-test.cmake)" ""
      '';

      env = base.env // {
        NIX_CFLAGS_COMPILE = base.env.NIX_CFLAGS_COMPILE + " -Wno-error=unknown-warning-option";
      };
    }
  );

  pluginArgs = {
    inherit obs-studio;
    stdenv = pkgs.llvmPackages.stdenv;
  };
in
{
  inherit obs-studio;

  obs-pipewire-audio-capture = (pkgs.obs-studio-plugins.obs-pipewire-audio-capture.override pluginArgs).overrideAttrs optimization.withCMakeClangMold;

  obs-vkcapture = (pkgs.obs-studio-plugins.obs-vkcapture.override pluginArgs).overrideAttrs optimization.withCMakeClangMold;
}
