FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    sbcl \
    rlwrap \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Quicklisp
RUN curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --non-interactive --load quicklisp.lisp \
         --eval "(quicklisp-quickstart:install)" \
         --eval "(quit)" && \
    rm quicklisp.lisp

# Manually append Quicklisp init to ~/.sbclrc (avoid interactive ql:add-to-init-file)
RUN echo ';;; Quicklisp init\n#-quicklisp\n(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp"\n(user-homedir-pathname))))\n  (when (probe-file quicklisp-init)\n    (load quicklisp-init)))' >> /root/.sbclrc

WORKDIR /app

CMD ["/bin/bash"]
