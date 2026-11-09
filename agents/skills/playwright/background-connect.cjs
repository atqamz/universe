if (process.env.PW_FOREGROUND !== "1") {
  const Base = globalThis.URL;
  class BackgroundConnectURL extends Base {
    constructor(input, base) {
      super(input, base);
      if (this.protocol === "chrome-extension:" && this.pathname.endsWith("/connect.html")) this.searchParams.set("background", "true");
    }
  }
  globalThis.URL = BackgroundConnectURL;
  const stringify = JSON.stringify;
  JSON.stringify = function (value, ...rest) {
    if (value && typeof value === "object" && value.method === "chrome.tabs.create" && Array.isArray(value.params) && value.params[0] && typeof value.params[0] === "object" && !("active" in value.params[0])) {
      value = { ...value, params: [{ ...value.params[0], active: false }, ...value.params.slice(1)] };
    }
    return stringify.call(this, value, ...rest);
  };
  const cp = require("child_process");
  const fs = require("fs");
  const hyprEnv = () => {
    if (process.env.HYPRLAND_INSTANCE_SIGNATURE) return process.env;
    const dir = `/run/user/${process.getuid()}/hypr`;
    try {
      const [newest] = fs.readdirSync(dir).map((name) => [name, fs.statSync(`${dir}/${name}`).mtimeMs]).sort((a, b) => b[1] - a[1]);
      return newest && { ...process.env, HYPRLAND_INSTANCE_SIGNATURE: newest[0] };
    } catch {}
  };
  const spawn = cp.spawn;
  cp.spawn = function (command, args, ...rest) {
    const env = Array.isArray(args) && args.some((a) => /^chrome-extension:\/\/[^/]+\/connect\.html/.test(a)) && hyprEnv();
    let before, active;
    try {
      const hypr = (what) => JSON.parse(cp.execFileSync("hyprctl", ["-j", what], { env }));
      if (env) [before, active] = [new Set(hypr("clients").map((c) => c.address)), hypr("activewindow").address];
    } catch {}
    if (!before) return spawn.call(this, command, args, ...rest);
    const child = spawn.call(this, command, ["--new-window", ...args], ...rest);
    const deadline = Date.now() + 3000;
    const poll = () => {
      try {
        const win = JSON.parse(cp.execFileSync("hyprctl", ["-j", "clients"], { env })).find((c) => c.class === "google-chrome" && !before.has(c.address));
        if (!win) return Date.now() < deadline && setTimeout(poll, 25);
        const focus = active ? `; dispatch hl.dsp.focus({ window = "address:${active}" })` : "";
        cp.execFileSync("hyprctl", ["--batch", `dispatch hl.dsp.window.move({ workspace = "special:pw", follow = false, window = "address:${win.address}" })${focus}`], { env });
      } catch {}
    };
    poll();
    return child;
  };
}
