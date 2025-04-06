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



    let sessionId = window.sessionStorage.getItem("terminal-session-id")
    if (!sessionId) {
      sessionId = crypto.randomUUID()
      window.sessionStorage.setItem("terminal-session-id", sessionId)
    }

    const topic = `terminal:${slug}`

    const channel = socket.channel(topic, { session_id: sessionId })
    channel.join()

    channel.on("output", ({ data }) => term.write(data))

    term.onData(data => {
      channel.push("input", { data });
    
      if (data === '\r') {
        // Force newline visually
        term.write('\r\n');
        return;
      }
    
      if (data === '\x7f') {
        // Handle backspace
        term.write('\b \b');
      } else {
        term.write(data);
      }
    });
    
    
    

  }
}
