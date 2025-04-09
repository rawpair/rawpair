export default {
    mounted() {
        const slug = this.el.dataset.slug
        const { protocol, hostname } = window.location
        const url = `${protocol}//${hostname}/terminal/${slug}`

        this.el.src = url
    }
}
