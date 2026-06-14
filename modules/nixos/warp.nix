_: {
  # Cloudflare WARP daemon (warp-svc). Connection is set up imperatively once
  # per host: `warp-cli registration new` then `warp-cli connect`.
  services.cloudflare-warp.enable = true;
}
