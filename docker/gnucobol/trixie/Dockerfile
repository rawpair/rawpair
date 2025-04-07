FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    gnucobol \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["/bin/bash"]
