{
  buildGoModule,
  fetchFromGitHub,
  lib,
  nix-update-script,
}:
buildGoModule rec {
  pname = "no-mistakes";
  version = "1.58.0";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "no-mistakes";
    rev = "v${version}";
    hash = "sha256-96ads0pudD1GMASFPVGln+Wbd/o8nFy+MxJxt7plqGI=";
  };

  vendorHash = "sha256-NZOYxNYvt4192uqKBdKRxdgrKFvWx3585psdCnRdPSM=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/kunchenguid/no-mistakes/internal/buildinfo.Version=${version}"
    "-X github.com/kunchenguid/no-mistakes/internal/buildinfo.TelemetryWebsiteID="
  ];

  subPackages = [ "cmd/no-mistakes" ];

  doCheck = false;

  passthru = {
    skill = "${src}/skills/no-mistakes/SKILL.md";
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Push-gate that validates and auto-fixes agent changes in an isolated worktree";
    homepage = "https://github.com/kunchenguid/no-mistakes";
    license = lib.licenses.mit;
    mainProgram = "no-mistakes";
    platforms = [ "x86_64-linux" ];
  };
}
