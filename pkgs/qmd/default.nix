{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  nodejs,
  node-gyp,
  python3,
  nix-update-script,
}:
buildNpmPackage rec {
  pname = "qmd";
  version = "2.5.3";

  src = fetchFromGitHub {
    owner = "tobi";
    repo = "qmd";
    tag = "v${version}";
    hash = "sha256-bFk078qQ8Ha/1na+r5ka6yNPI/Pealh0Rk6hJxKBwNs=";
  };

  patches = [ ./mcp-require-explicit-collections.patch ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-J11B/PeRD1wmetp7Vi6yiT77xmgicM8pB4dP+hoQKws=";

  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    node-gyp
    python3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libvulkan.so.1"
    "libcuda.so.1"
    "libcudart.so.12"
    "libcublas.so.12"
    "libcudart.so.13"
    "libcublas.so.13"
  ];

  preBuild = ''
    (cd node_modules/better-sqlite3 && node-gyp rebuild --release)
  '';

  postInstall = ''
    wrapProgram $out/bin/qmd \
      --set QMD_LLAMA_GPU false \
      --prefix PATH : ${nodejs}/bin
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "On-device hybrid search engine for markdown files with BM25, vector search, and LLM reranking";
    homepage = "https://github.com/tobi/qmd";
    license = lib.licenses.mit;
    mainProgram = "qmd";
    platforms = [ "x86_64-linux" ];
  };
}
