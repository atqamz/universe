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
}
