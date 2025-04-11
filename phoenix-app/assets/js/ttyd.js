// SPDX-License-Identifier: MPL-2.0

export default {
    mounted() {
        const slug = this.el.dataset.slug
        const terminalBaseUrl = this.el.dataset.terminalBaseUrl
        const url = `${terminalBaseUrl}terminal/${slug}`

        this.el.src = url
    }
}
