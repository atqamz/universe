{
  alsa-lib,
  autoPatchelfHook,
  fetchurl,
  lib,
  libGL,
  libpulseaudio,
  libx11,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  makeWrapper,
  noto-fonts-cjk-sans,
  nix-update-script,
  stdenv,
  stdenvNoCC,
  wayland,
}:
let
  runtimeLibs = [
    libxkbcommon
    wayland
    libGL
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "fastpotify";
  version = "0.5.0";

  src = fetchurl {
    url = "https://github.com/crmne/fastpotify/releases/download/v${finalAttrs.version}/fastpotify-v${finalAttrs.version}-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-YW+CA4hqqTA4xf/QWbNoNrYlmvboS3iVHSUGI5X5b2w=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    libpulseaudio
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 fastpotify "$out/bin/fastpotify"
    install -Dm644 packaging/applications/fastpotify.desktop "$out/share/applications/fastpotify.desktop"
    install -Dm644 packaging/icons/fastpotify.svg "$out/share/icons/hicolor/scalable/apps/fastpotify.svg"
    install -Dm644 README.md "$out/share/doc/fastpotify/README.md"
    install -Dm644 LICENSE "$out/share/licenses/fastpotify/LICENSE"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/fastpotify" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix XDG_DATA_DIRS : ${noto-fonts-cjk-sans}/share
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Fast native Spotify client with local playback and Spotify Connect";
    homepage = "https://fastpotify.rocks";
    license = lib.licenses.mit;
    mainProgram = "fastpotify";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
