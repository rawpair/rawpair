import "phoenix_html"

// @ts-ignore
import {Socket} from "phoenix"
// @ts-ignore
import {LiveSocket} from "phoenix_live_view"
// @ts-ignore
import topbar from "../vendor/topbar"
// @ts-ignore
import EditorHook from './editor'
// @ts-ignore
import TtydHook from "./ttyd"

let Hooks = {
  // TerminalHook,
  EditorHook,
  TtydHook
}

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()

// @ts-ignore
window.liveSocket = liveSocket