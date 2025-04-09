export default {
    mounted() {
        const port = this.el.dataset.port
        const { protocol, hostname } = window.location
        const url = `${protocol}//${hostname}:${port}`

        this.el.src = url
    }
}
