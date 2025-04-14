# Docker images

These images are designed to work on RawPair.

## Docker Hub

You can find x64 versions of most images on https://hub.docker.com/repositories/rawpair

Dedicated arm64 versions of these images will soon be available.

### Building images

Either run individual commands like:

`docker build -f gnucobol/trixie/Dockerfile -t gnucobol:trixie .`
`docker build -f ocaml/ubuntu-2404/Dockerfile -t ocaml:ubuntu-2404 .`

Or run `./build-images.sh`. 

You can filter by language, i.e. `./build-images.sh --filter=ada`

You can perform a dry run, i.e. `./build-images.sh --filter=ada --dry-run`

### Pruning builder cache

`docker builder prune --all --force`

### Useful links if you wish to tweak Vector log forwarding

https://vector.dev/docs/reference/vrl/functions/#replace
https://vector.dev/docs/reference/vrl/functions/#strip_whitespace
https://vector.dev/docs/reference/vrl/functions/#strip_ansi_escape_codes