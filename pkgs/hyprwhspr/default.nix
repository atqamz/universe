{
  fetchFromGitHub,
  lib,
  makeWrapper,
  nix-update-script,
  pkgs,
  stdenvNoCC,
}:
let
  python = pkgs.python3.withPackages (
    pythonPackages: with pythonPackages; [
      evdev
      numpy
      pulsectl
      pyperclip
      pyudev
      rich
      sounddevice
      soundfile
      soxr
    ]
  );
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

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/hyprwhspr" "$out/bin"
    cp -R bin config lib share requirements*.txt "$out/lib/hyprwhspr/"
    substituteInPlace "$out/lib/hyprwhspr/bin/hyprwhspr" \
      --replace-fail 'SYSTEM_PYTHON_CANDIDATES=(' 'SYSTEM_PYTHON_CANDIDATES=(
        ${python}/bin/python3'
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
      --prefix PATH : ${
        lib.makeBinPath [
          python
          pkgs.bash
          pkgs.coreutils
          pkgs.git
          pkgs.hyprland
          pkgs.libnotify
          pkgs.pipewire
          pkgs.procps
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

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "System-wide speech-to-text for Linux desktops";
    homepage = "https://github.com/goodroot/hyprwhspr";
    license = lib.licenses.mit;
    mainProgram = "hyprwhspr";
    platforms = [ "x86_64-linux" ];
  };
})
