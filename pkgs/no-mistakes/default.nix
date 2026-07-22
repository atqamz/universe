{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule rec {
  pname = "no-mistakes";
  version = "1.40.0";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "no-mistakes";
    rev = "v${version}";
    hash = "sha256-13ApAoPhwk5YlkJ+huT9VYpIpRW1rFHbfAkrPjfkevI=";
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

  meta = {
    description = "Push-gate that validates and auto-fixes agent changes in an isolated worktree";
    homepage = "https://github.com/kunchenguid/no-mistakes";
    license = lib.licenses.mit;
    mainProgram = "no-mistakes";
    platforms = [ "x86_64-linux" ];
  };
}
