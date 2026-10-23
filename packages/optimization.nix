{ lib, pkgs }:

let
  moldEnv = old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.mold ];
    env = (old.env or { }) // {
      NIX_CFLAGS_COMPILE = toString (old.env.NIX_CFLAGS_COMPILE or "") + " -march=x86-64-v3 -O3";
      NIX_CFLAGS_LINK = toString (old.env.NIX_CFLAGS_LINK or "") + " -fuse-ld=mold";
    };
  };

  ltoFlagFor =
    ltoMode: stdenv:
    let
      isClang = stdenv.cc.isClang or false;
    in
    if ltoMode == "none" then
      ""
    else if ltoMode == "thin" then
      if isClang then " -flto=thin" else " -flto"
    else if isClang then
      " -flto=full"
    else
      " -flto";

  mesonLtoModeFor = ltoMode: if ltoMode == "thin" then "thin" else "default";

  cgoDisabled =
    attrs:
    let
      env = attrs.env or { };
      v = env.CGO_ENABLED or (attrs.CGO_ENABLED or "");
    in
    toString v == "0";

  withCMakeClangMoldMode =
    ltoMode: old:
    let
      base = moldEnv old;
      stdenv = old.stdenv or pkgs.stdenv;
      ltoFlag = ltoFlagFor ltoMode stdenv;
      isClang = stdenv.cc.isClang or false;
    in
    base
    // {
      doCheck = false;
      cmakeFlags =
        (old.cmakeFlags or [ ])
        ++ lib.optional (ltoMode != "none") "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON"
        ++ lib.optional (ltoMode != "none" && isClang) "-DCMAKE_AR=${pkgs.llvmPackages.bintools}/bin/ar"
        ++ lib.optional (
          ltoMode != "none" && isClang
        ) "-DCMAKE_RANLIB=${pkgs.llvmPackages.bintools}/bin/ranlib";
      nativeBuildInputs =
        base.nativeBuildInputs ++ lib.optional (ltoMode != "none" && isClang) pkgs.llvmPackages.bintools;
      env = base.env // {
        NIX_CFLAGS_COMPILE = base.env.NIX_CFLAGS_COMPILE + ltoFlag;
        NIX_CFLAGS_LINK = base.env.NIX_CFLAGS_LINK + ltoFlag;
      };
    };

  withMesonClangMoldMode =
    ltoMode: old:
    let
      base = moldEnv old;
      ltoFlag = ltoFlagFor ltoMode (old.stdenv or pkgs.stdenv);
    in
    base
    // {
      doCheck = false;
      mesonFlags =
        (old.mesonFlags or [ ])
        ++ lib.optional (ltoMode != "none") "-Db_lto=true"
        ++ lib.optional (ltoMode != "none") "-Db_lto_mode=${mesonLtoModeFor ltoMode}"
        ++ [
          "-Db_ndebug=true"
          "-Dstrip=true"
        ];
      env = base.env // {
        NIX_CFLAGS_COMPILE = base.env.NIX_CFLAGS_COMPILE + ltoFlag;
        NIX_CFLAGS_LINK = base.env.NIX_CFLAGS_LINK + ltoFlag;
      };
    };

  withGoFlags =
    base: attrs:
    base
    // {
      doCheck = false;
      ldflags = [
        "-s"
        "-w"
      ]
      ++ (attrs.ldflags or [ ]);
      env = (base.env or { }) // {
        GOAMD64 = "v3";
        GOFLAGS = "-trimpath";
      };
    };
in
{
  inherit withCMakeClangMoldMode withMesonClangMoldMode;

  withCMakeClangMold = withCMakeClangMoldMode "full";

  llvmStdenv = pkg: pkg.override { stdenv = pkgs.llvmPackages.stdenv; };

  llvmStdenvWithArgs =
    extraArgs: pkg: pkg.override (extraArgs // { stdenv = pkgs.llvmPackages.stdenv; });

  withGoOverride = old: withGoFlags (if cgoDisabled old then old else moldEnv old) old;

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
      base = if cgoDisabled b then b else moldEnv b;
    in
    go (withGoFlags (b // base) b);

  withMesonClangMold = withMesonClangMoldMode "full";

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
