{ pkgs, lib, ... }:
let
  dotnetSdk = pkgs.dotnet-sdk_10;
  tools = with pkgs; [
    nixd
    go
    gopls
    rust-analyzer
    pyright
    typescript-language-server
  ];
  zed = pkgs.symlinkJoin {
    name = "zed";
    paths = [ pkgs.zed-editor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/zeditor
      makeWrapper ${pkgs.zed-editor}/bin/zeditor $out/bin/zeditor \
        --set DOTNET_ROOT ${dotnetSdk.unwrapped}/share/dotnet \
        --prefix PATH : ${lib.makeBinPath tools}
      ln -s zeditor $out/bin/zed
    '';
  };
in
{
  home.packages = [ zed ];
}
