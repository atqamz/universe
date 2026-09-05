{
  fetchFromGitHub,
  lib,
  makeWrapper,
  nix-update-script,
  pkgs,
  stdenvNoCC,
}:
let
  pythonBase = pkgs.python313;
  python = pythonBase.withPackages (
    pythonPackages: with pythonPackages; [
      evdev
      numpy
      pulsectl
      pyperclip
      pyudev
      requests
      rich
      sounddevice
      soundfile
      soxr
    ]
  );
  hyprctlShim = pkgs.writeShellScriptBin "hyprctl" ''
    exec ${pkgs.coreutils}/bin/env -u LD_LIBRARY_PATH -u LD_PRELOAD ${pkgs.hyprland}/bin/hyprctl "$@"
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hyprwhspr";
  version = "1.43.0";

  src = fetchFromGitHub {
    owner = "goodroot";
    repo = "hyprwhspr";
    rev = "v${finalAttrs.version}";
    hash = "sha256-qDBxyy4pNuyGv+gUuJgQ0usyDA/PcWgLZjd4UH5Y0Q8=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  doInstallCheck = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/hyprwhspr" "$out/bin"
    cp -R bin config lib share requirements*.txt "$out/lib/hyprwhspr/"
    substituteInPlace "$out/lib/hyprwhspr/bin/hyprwhspr" \
      --replace-fail 'SYSTEM_PYTHON_CANDIDATES=(' 'SYSTEM_PYTHON_CANDIDATES=(
        ${python}/bin/python3'
    substituteInPlace "$out/lib/hyprwhspr/lib/src/backend_installer.py" \
      --replace-fail 'SYSTEM_PYTHON_CANDIDATES = (' 'SYSTEM_PYTHON_CANDIDATES = (
    "${pythonBase}/bin/python3",'
    substituteInPlace "$out/lib/hyprwhspr/lib/src/cli/_shared.py" \
      --replace-fail 'version = "0.1.0"' 'version = "${pkgs.ydotool.version}"'
    substituteInPlace "$out/lib/hyprwhspr/requirements.txt" \
      --replace-fail 'rich>=14.0.0' 'rich>=14.0.0
    requests'
    substituteInPlace "$out/lib/hyprwhspr/lib/cli.py" \
      --replace-fail "return 'unknown'" "return 'v${finalAttrs.version}'"
    substituteInPlace "$out/lib/hyprwhspr/config/systemd/hyprwhspr.service" \
      --replace-fail '/bin/bash' '${pkgs.bash}/bin/bash' \
      --replace-fail '$(seq 1 60)' '$(${pkgs.coreutils}/bin/seq 1 60)' \
      --replace-fail 'sleep 0.25' '${pkgs.coreutils}/bin/sleep 0.25' \
      --replace-fail 'pkill -9' '${pkgs.procps}/bin/pkill -9' \
      --replace-fail 'ExecStart=/usr/lib/hyprwhspr/bin/hyprwhspr' "ExecStart=$out/bin/hyprwhspr" \
      --replace-fail 'Environment=HYPRWHSPR_ROOT=/usr/lib/hyprwhspr' "Environment=HYPRWHSPR_ROOT=$out/lib/hyprwhspr"
    install -Dm644 README.md "$out/share/doc/hyprwhspr/README.md"
    install -Dm644 LICENSE "$out/share/licenses/hyprwhspr/LICENSE"
    makeWrapper "$out/lib/hyprwhspr/bin/hyprwhspr" "$out/bin/hyprwhspr" \
      --prefix C_INCLUDE_PATH : ${pkgs.linuxHeaders}/include \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          pkgs.stdenv.cc.cc.lib
          pkgs.portaudio
          pkgs.zlib
          pkgs.libpulseaudio
          pkgs.systemdLibs
        ]
      } \
      --prefix PATH : ${
        lib.makeBinPath [
          python
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          hyprctlShim
          pkgs.hyprland
          pkgs.libnotify
          pkgs.pipewire
          pkgs.procps
          pkgs.pulseaudio
          pkgs.systemd
          pkgs.wl-clipboard
          pkgs.wtype
          pkgs.xclip
          pkgs.xdotool
          pkgs.xprop
          pkgs.ydotool
        ]
      }
    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    MISE_SHELL=bash \
      PATH=${lib.makeBinPath [ pkgs.ydotool ]} \
      PYTHONPATH="$out/lib/hyprwhspr/lib" \
      ${python}/bin/python3 - <<'PY'
    from src.backend_installer import _find_compatible_python
    from src.cli._shared import _check_ydotool_version

    python, _ = _find_compatible_python()
    assert python == "${pkgs.python313}/bin/python3", python
    compatible, version, _ = _check_ydotool_version()
    assert compatible, version
    PY
    ${pkgs.gnugrep}/bin/grep -Fx requests "$out/lib/hyprwhspr/requirements.txt"
    runHook postInstallCheck
  '';

  passthru.updateScript = nix-update-script { };
  passthru.hyprctlShim = hyprctlShim;

  meta = {
    description = "System-wide speech-to-text for Linux desktops";
    homepage = "https://github.com/goodroot/hyprwhspr";
    license = lib.licenses.mit;
    mainProgram = "hyprwhspr";
    platforms = [ "x86_64-linux" ];
  };
})
