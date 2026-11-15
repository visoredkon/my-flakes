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
  graalvm =
    (pkgs.graalvmPackages."graalvm-oracle_${lib.versions.major release.graalvmVersion}"
      or (throw "metrolist: nixpkgs has no graalvm-oracle_${lib.versions.major release.graalvmVersion}; update flake.lock")
    ).overrideAttrs
      (_: {
        version = release.graalvmVersion;
        src = pkgs.fetchurl {
          url = release.graalvmUrl;
          hash = release.graalvmSha256;
        };
      });

  nativeLinkInputs = with pkgs; [
    alsa-lib
    freetype
    libx11
    libxext
    libxi
    libxrender
    libxtst
    zlib
  ];

  runtimeLibs = with pkgs; [
    fontconfig
    gtk3
    libGL
    libsecret
    webkitgtk_4_1
  ];

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
      pkgs.cacert
      pkgs.python3
    ];

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = release.gradleDepsHash;

    dontFixup = true;

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
        -I scripts/desktop-native-image/prepare.init.gradle \
        -PnativeExperimentDir=$TMPDIR/native-work \
        -Pmetrolist.debug=false \
        :desktopApp:prepareNativeImage

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
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
    pkgs.python3
    pkgs.wrapGAppsHook3
  ];

  buildInputs =
    nativeLinkInputs
    ++ (with pkgs; [
      gdk-pixbuf
      glib-networking
      gsettings-desktop-schemas
      gtk3
    ]);

  strictDeps = true;
  dontStrip = true;

  postPatch = ''
    cp -r ${metroproto}/. metroproto/
    cp -r ${opus}/. opusDecoder/src/main/jni/libopus/
    chmod -R u+w metroproto opusDecoder/src/main/jni/libopus

    substituteInPlace scripts/desktop-native-image/native_image.py \
      --replace-fail "-J-Xmx12g" "-J-Xmx10g" \
      --replace-fail "'-Os'" "'-O3'"

    if grep -q -- "-march=compatibility" scripts/desktop-native-image/native_image.py; then
      substituteInPlace scripts/desktop-native-image/native_image.py \
        --replace-fail "-march=compatibility" "-march=x86-64-v3"
    fi
  '';

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    export GRADLE_USER_HOME=$TMPDIR/gradle-home
    export JAVA_HOME=${jdk}
    export LOCAL_MAVEN_REPO=${gradleDeps}
    export LIBRARY_PATH=${lib.makeLibraryPath nativeLinkInputs}

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
      -I scripts/desktop-native-image/prepare.init.gradle \
      -Dorg.gradle.java.installations.paths=${jdk} \
      -Dorg.gradle.java.installations.auto-download=false \
      -PappVersion=${release.version} \
      -PnativeExperimentDir=$TMPDIR/native-work \
      -Pmetrolist.debug=false \
      -Pmetrolist.sourceRevision=${release.rev} \
      :desktopApp:prepareNativeImage

    : > "$TMPDIR/native-work/build.log"

    python3 scripts/desktop-native-image/native_image.py \
      --platform linux-x64 \
      --work $TMPDIR/native-work \
      --graalvm ${graalvm} \
      --inside-scope &
    native_pid=$!

    stdbuf -oL -eL tail -n +1 -F --pid="$native_pid" "$TMPDIR/native-work/build.log" &
    tail_pid=$!

    status=0
    wait "$native_pid" || status=$?
    wait "$tail_pid" || true

    if (( status != 0 )); then
      exit "$status"
    fi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/opt/metrolist/lib/native \
      $out/share/applications \
      $out/share/icons/hicolor/512x512/apps

    cp -a $TMPDIR/native-work/image/. $out/opt/metrolist/lib/native/
    ln -s lib/native/resources $out/opt/metrolist/resources
    install -Dm755 scripts/desktop-native-image/linux-launcher.sh \
      $out/opt/metrolist/bin/Metrolist

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

    makeWrapper $out/opt/metrolist/bin/Metrolist $out/bin/metrolist \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.coreutils
          pkgs.gnused
        ]
      } \
      --set-default GIO_EXTRA_MODULES ${pkgs.glib-networking}/lib/gio/modules

    runHook postInstall
  '';

  passthru.gradleDeps = gradleDeps;

  meta = {
    description = "YouTube Music desktop client (GraalVM native image)";
    homepage = "https://github.com/MetrolistGroup/Metrolist";
    license = lib.licenses.gpl3Only;
    mainProgram = "metrolist";
    platforms = [ "x86_64-linux" ];
  };
}
