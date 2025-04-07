FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    gnat \
    make \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /src

CMD ["/bin/bash"]
