_: {
  # earlyoom kills the heaviest process under memory pressure before the kernel
  # OOM-killer kicks in, which on a desktop otherwise freezes the whole session
  # (Unity + browser can exhaust RAM). Upstream defaults (act at 10% free mem /
  # swap) are sane; keep them.
  services.earlyoom.enable = true;
}
