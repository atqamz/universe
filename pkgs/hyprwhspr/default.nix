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
  visualizerPythonPath = lib.makeSearchPath pythonBase.sitePackages [
    pythonBase.pkgs.pycairo
    pythonBase.pkgs.pygobject3
  ];
  visualizerDependencies = lib.closePropagation [
    pkgs.gobject-introspection
    pkgs.gtk4
    pkgs.gtk4-layer-shell
  ];
  visualizerTypelibPath = lib.makeSearchPath "lib/girepository-1.0" (
    visualizerDependencies ++ map (dependency: dependency.out or dependency) visualizerDependencies
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

  postPatch = ''
    substituteInPlace lib/src/cli/models.py \
      --replace-fail "glob('models--Systran--faster-whisper-*')" "glob('models--*--faster-whisper-*')" \
      --replace-fail "model_dir.name.replace('models--Systran--faster-whisper-', ''')" "model_dir.name.split('--faster-whisper-', 1)[1]"
    substituteInPlace lib/mic_osd/runner.py \
      --replace-fail '        for pattern in [' '        for pattern in [
            "${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so.0",'
  '';

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
      --prefix GI_TYPELIB_PATH : ${visualizerTypelibPath} \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          pkgs.gtk4
          pkgs.gtk4-layer-shell
          pkgs.stdenv.cc.cc.lib
          pkgs.portaudio
          pkgs.zlib
          pkgs.libpulseaudio
          pkgs.systemdLibs
        ]
      } \
      --prefix PYTHONPATH : ${visualizerPythonPath} \
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
    GI_TYPELIB_PATH=${visualizerTypelibPath} \
      LD_LIBRARY_PATH=${
        lib.makeLibraryPath [
          pkgs.gtk4
          pkgs.gtk4-layer-shell
        ]
      } \
      MISE_SHELL=bash \
      PATH=${lib.makeBinPath [ pkgs.ydotool ]} \
      PYTHONPATH="$out/lib/hyprwhspr/lib:${visualizerPythonPath}" \
      ${python}/bin/python3 - <<'PY'
    from src.backend_installer import _find_compatible_python
    from src.cli._shared import _check_ydotool_version
    from src.cli.models import faster_whisper_model_status
    from mic_osd.runner import MicOSDRunner
    import cairo
    import contextlib
    import gi
    import io
    import os
    import tempfile
    from pathlib import Path

    gi.require_version("Gtk", "4.0")
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk, Gtk4LayerShell

    layer_shell = "${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so.0"
    preload = MicOSDRunner._layer_shell_ld_preload()
    assert os.path.samefile(preload, layer_shell)
    assert MicOSDRunner._layer_shell_environment()["LD_PRELOAD"].split()[0] == preload
    python, _ = _find_compatible_python()
    assert python == "${pkgs.python313}/bin/python3", python
    compatible, version, _ = _check_ydotool_version()
    assert compatible, version
    with tempfile.TemporaryDirectory() as home:
        os.environ["HOME"] = home
        model = Path(home) / ".cache/huggingface/hub/models--mobiuslabsgmbh--faster-whisper-large-v3-turbo"
        model.mkdir(parents=True)
        (model / "model.bin").write_bytes(b"model")
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            faster_whisper_model_status()
        assert "- large-v3-turbo" in output.getvalue(), output.getvalue()
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
