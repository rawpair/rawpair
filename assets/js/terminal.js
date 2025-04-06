import { Terminal } from "@xterm/xterm"

import { Socket } from "phoenix"

export default {
  mounted() {
    const term = new Terminal({
      cursorBlink: true,
      cursorStyle: 'block',
    })
    term.open(this.el)

    const slug = this.el.dataset.slug
    const socket = new Socket("/socket")
    socket.connect()

    const channel = socket.channel(`terminal:${slug}`)
    channel.join()

    channel.on("output", ({ data }) => term.write(data))

    term.onData(data => {
      channel.push("input", { data })

      // Echo it manually *except* for newline
      if (data !== "\r") {
        term.write(data)
      }
    })
  }
}
