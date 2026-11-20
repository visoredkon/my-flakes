{
  lib,
  pkgs,
  release,
  owner,
  repo,
  ...
}:

let
  inherit (release) version;

  src = pkgs.fetchFromGitHub {
    inherit owner repo;
    inherit (release) rev;
    hash = release.sourceSha256;
  };

  metroproto = pkgs.fetchFromGitHub {
    owner = "MetrolistGroup";
    repo = "metroproto";
    rev = release.metroprotoRev;
    hash = release.metroprotoSha256;
  };

  opus = pkgs.fetchFromGitHub {
    owner = "xiph";
    repo = "opus";
    rev = release.opusRev;
    hash = release.opusSha256;
  };

  jdk =
    pkgs."temurin-bin-${release.jdkMajor}"
      or (throw "metrolist: nixpkgs has no temurin-bin-${release.jdkMajor}; update flake.lock");
  gradle =
    pkgs."gradle_${release.gradleMajor}"
      or (throw "metrolist: nixpkgs has no gradle_${release.gradleMajor}; update flake.lock");

  runtimeLibs = with pkgs; [
    alsa-lib
    dbus.lib
    flac.out
    fontconfig
    glib
    gtk3
    libGL
    libsecret
    libx11
    libxext
    libxi
    libxrender
    libxtst
    stdenv.cc.cc.lib
    webkitgtk_4_1
    zlib
  ];

  fixJlinkCds = ''
    substituteInPlace desktopApp/build.gradle.kts \
      --replace-fail 'File(toolchainHome.get(), "bin/$javaName").copyTo(java, overwrite = true)' \
      'listOf(File(toolchainHome.get(), "bin/.$javaName-wrapped"), File(toolchainHome.get(), "bin/$javaName")).first { it.isFile }.copyTo(java, overwrite = true)' \
      --replace-fail 'val cdsOptions = desktopMemoryJvmArgs.toList()' \
      'val cdsOptions = desktopMemoryJvmArgs.toList() + listOf("--add-opens=java.base/java.lang=ALL-UNNAMED", "--add-opens=java.desktop/sun.awt=ALL-UNNAMED", "--add-opens=java.desktop/java.awt=ALL-UNNAMED", "--add-opens=java.desktop/sun.swing=ALL-UNNAMED", "--add-opens=jdk.security.auth/com.sun.security.auth.module=ALL-UNNAMED", "--add-opens=java.desktop/sun.awt.X11=ALL-UNNAMED", "--enable-native-access=ALL-UNNAMED")'
  '';

  gradleDeps = pkgs.stdenvNoCC.mkDerivation {
    pname = "metrolist-gradle-deps";
    inherit
      version
      src
      metroproto
      opus
      ;

    nativeBuildInputs = [
      gradle
      jdk
      pkgs.binutils
      pkgs.cacert
      pkgs.python3
    ];

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = release.gradleDepsHash;

    dontFixup = true;

    postPatch = fixJlinkCds;

    buildPhase = ''
      runHook preBuild

      export HOME=$TMPDIR
      export GRADLE_USER_HOME=$TMPDIR/gradle-home
      export JAVA_HOME=${jdk}

      cp -r ${metroproto}/. metroproto/
      cp -r ${opus}/. opusDecoder/src/main/jni/libopus/
      chmod -R u+w metroproto opusDecoder/src/main/jni/libopus

      ${gradle}/bin/gradle \
        --no-daemon \
        --no-build-cache \
        --no-configuration-cache \
        -Dorg.gradle.java.installations.paths=${jdk} \
        -Dorg.gradle.java.installations.auto-download=false \
        -PappVersion=${version} \
        -Pmetrolist.debug=false \
        :desktopApp:createReleaseDistributable

      python3 - "$GRADLE_USER_HOME/caches/modules-2/files-2.1" "$out" <<'PY'
      import pathlib
      import shutil
      import sys

      source = pathlib.Path(sys.argv[1])
      destination = pathlib.Path(sys.argv[2])
      for group in source.iterdir():
          if not group.is_dir():
              continue
          group_path = destination.joinpath(*group.name.split("."))
          for artifact in group.iterdir():
              if not artifact.is_dir():
                  continue
              for version in artifact.iterdir():
                  if not version.is_dir():
                      continue
                  target = group_path / artifact.name / version.name
                  target.mkdir(parents=True, exist_ok=True)
                  for digest in version.iterdir():
                      if not digest.is_dir():
                          continue
                      for entry in digest.iterdir():
                          if not entry.is_file():
                              continue
                          target_entry = target / entry.name
                          shutil.copy2(entry, target_entry)
                          canonical = f"{artifact.name}-{version.name}{entry.suffix}"
                          if entry.name != canonical and entry.suffix in (
                              ".aar",
                              ".jar",
                              ".klib",
                              ".module",
                              ".pom",
                              ".zip",
                          ):
                              canonical_entry = target / canonical
                              if not canonical_entry.exists():
                                  shutil.copy2(entry, canonical_entry)
      PY

      runHook postBuild
    '';

    installPhase = ":";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "metrolist";
  inherit version src;

  nativeBuildInputs = [
    gradle
    jdk
    pkgs.binutils
    pkgs.makeWrapper
    pkgs.python3
  ];

  buildInputs = with pkgs; [
    gdk-pixbuf
    glib-networking
    gsettings-desktop-schemas
    gtk3
  ];

  strictDeps = true;
  dontStrip = true;

  postPatch = fixJlinkCds + ''
    cp -r ${metroproto}/. metroproto/
    cp -r ${opus}/. opusDecoder/src/main/jni/libopus/
    chmod -R u+w metroproto opusDecoder/src/main/jni/libopus
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    export GRADLE_USER_HOME=$TMPDIR/gradle-home
    export JAVA_HOME=${jdk}
    export LOCAL_MAVEN_REPO=${gradleDeps}
    export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive

    cat > "$TMPDIR/local-repo.init.gradle" <<EOF
    def deps = System.getenv('LOCAL_MAVEN_REPO')
    beforeSettings { settings ->
      settings.pluginManagement.repositories { maven { url = uri(deps) } }
      settings.dependencyResolutionManagement.repositories { maven { url = uri(deps) } }
    }
    allprojects { buildscript.repositories { maven { url = uri(deps) } } }
    EOF

    ${gradle}/bin/gradle \
      --offline \
      --no-daemon \
      --no-build-cache \
      --no-configuration-cache \
      -I "$TMPDIR/local-repo.init.gradle" \
      -Dorg.gradle.java.installations.paths=${jdk} \
      -Dorg.gradle.java.installations.auto-download=false \
      -PappVersion=${release.version} \
      -Pmetrolist.debug=false \
      -Pmetrolist.sourceRevision=${release.rev} \
      :desktopApp:createReleaseDistributable

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/metrolist \
      $out/share/applications \
      $out/share/icons/hicolor/512x512/apps

    cp -a desktopApp/build/compose/binaries/main-release/app/Metrolist/. $out/opt/metrolist/

    install -Dm644 desktopApp/src/desktopMain/resources/logo.png \
      $out/share/icons/hicolor/512x512/apps/metrolist.png

    cat > $out/share/applications/metrolist.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Metrolist
    Exec=metrolist %u
    Icon=metrolist
    StartupWMClass=Metrolist
    Comment=YouTube Music desktop client
    Categories=AudioVideo;Player;
    Terminal=false
    MimeType=x-scheme-handler/metrolist;x-scheme-handler/metrolist-auth;
    EOF

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/opt/metrolist/bin/Metrolist $out/bin/metrolist \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.coreutils
          pkgs.gnused
        ]
      } \
      --set-default GIO_EXTRA_MODULES ${pkgs.glib-networking}/lib/gio/modules \
      --set GDK_PIXBUF_MODULE_FILE ${pkgs.gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache \
      --set GSETTINGS_SCHEMA_DIR ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas \
      --prefix XDG_DATA_DIRS : ${pkgs.gtk3}/share
  '';

  passthru.gradleDeps = gradleDeps;

  meta = {
    description = "YouTube Music desktop client (JVM)";
    homepage = "https://github.com/MetrolistGroup/Metrolist";
    license = lib.licenses.gpl3Only;
    mainProgram = "metrolist";
    platforms = [ "x86_64-linux" ];
  };
}
