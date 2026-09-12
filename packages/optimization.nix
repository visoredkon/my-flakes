{ pkgs }:

let
  moldEnv = old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.mold ];
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = toString (old.env.NIX_CFLAGS_COMPILE or "") + " -march=x86-64-v3 -O3";
      NIX_CFLAGS_LINK = toString (old.env.NIX_CFLAGS_LINK or "") + " -fuse-ld=mold";
    };
  };
in
{
  inherit moldEnv;

  withCMakeClangMold =
    old:
    (moldEnv old)
    // {
      doCheck = false;
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [
        "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON"
      ];
    };

  withGoOptimizations =
    {
      goBuilder ? pkgs.buildGoModule,
      stdenv ? pkgs.llvmPackages.stdenv,
      ...
    }@args:
    let
      b = removeAttrs args [
        "goBuilder"
        "stdenv"
      ];
      go = goBuilder.override { inherit stdenv; };
    in
    go (
      b
      // {
        env = (b.env or { }) // {
          GOAMD64 = "v3";
          GOFLAGS = "-trimpath";
          NIX_CFLAGS_LINK = "-fuse-ld=mold";
        };
        ldflags = [
          "-s"
          "-w"
        ]
        ++ (b.ldflags or [ ]);
        nativeBuildInputs = (b.nativeBuildInputs or [ ]) ++ [ pkgs.mold ];
      }
    );

  withMesonClangMold =
    old:
    (moldEnv old)
    // {
      mesonFlags = (old.mesonFlags or [ ]) ++ [
        "-Db_lto=true"
        "-Db_lto_mode=thin"
        "-Db_ndebug=true"
        "-Dstrip=true"
      ];
    };

  withRustOptimizations =
    {
      lto ? "thin",
    }:
    old: {
      doCheck = false;
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.mold ];
      env = (old.env or { }) // {
        RUSTFLAGS =
          toString (old.env.RUSTFLAGS or "") + " -C link-arg=-fuse-ld=mold" + " -C target-cpu=x86-64-v3";
        CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "1";
        CARGO_PROFILE_RELEASE_LTO = lto;
        CARGO_PROFILE_RELEASE_PANIC = "abort";
      };
    };
}
