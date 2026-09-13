{ pkgs }:

let
  moldEnv = old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.mold ];
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = toString (old.env.NIX_CFLAGS_COMPILE or "") + " -march=x86-64-v3 -O3";
      NIX_CFLAGS_LINK = toString (old.env.NIX_CFLAGS_LINK or "") + " -fuse-ld=mold";
    };
  };

  withMesonClangMoldMode =
    ltoMode: old:
    (moldEnv old)
    // {
      doCheck = false;
      mesonFlags = (old.mesonFlags or [ ]) ++ [
        "-Db_lto=true"
        "-Db_lto_mode=${ltoMode}"
        "-Db_ndebug=true"
        "-Dstrip=true"
      ];
    };
in
{
  inherit withMesonClangMoldMode;

  withCMakeClangMold =
    old:
    let
      base = moldEnv old;
    in
    base
    // {
      doCheck = false;
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [
        "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON"
      ];
      env = base.env // {
        NIX_CFLAGS_COMPILE = base.env.NIX_CFLAGS_COMPILE + " -flto";
        NIX_CFLAGS_LINK = base.env.NIX_CFLAGS_LINK + " -flto";
      };
    };

  withGoOptimizations =
    {
      goBuilder ? pkgs.buildGo126Module,
      stdenv ? pkgs.llvmPackages.stdenv,
      ...
    }@args:
    let
      b = removeAttrs args [
        "goBuilder"
        "stdenv"
      ];
      go = goBuilder.override { inherit stdenv; };
      base = moldEnv b;
    in
    go (
      b
      // base
      // {
        doCheck = false;
        ldflags = [
          "-s"
          "-w"
        ]
        ++ (b.ldflags or [ ]);
        env = base.env // {
          GOAMD64 = "v3";
          GOFLAGS = "-trimpath";
        };
      }
    );

  withMesonClangMold = withMesonClangMoldMode "default";

  withRustOptimizations =
    old:
    let
      base = moldEnv old;
    in
    base
    // {
      doCheck = false;
      env = base.env // {
        RUSTFLAGS =
          toString (old.env.RUSTFLAGS or "") + " -C link-arg=-fuse-ld=mold" + " -C target-cpu=x86-64-v3";
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
        CARGO_PROFILE_RELEASE_LTO = "fat";
        CARGO_PROFILE_RELEASE_PANIC = "abort";
      };
    };
}
