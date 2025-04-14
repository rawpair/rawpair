### Useful links

https://vector.dev/docs/reference/vrl/functions/#replace
https://vector.dev/docs/reference/vrl/functions/#strip_whitespace
https://vector.dev/docs/reference/vrl/functions/#strip_ansi_escape_codes

### Building images

Either run individual commands like:

`docker build -f gnucobol/trixie/Dockerfile -t gnucobol:trixie .`
`docker build -f ocaml/ubuntu-2404/Dockerfile -t ocaml:ubuntu-2404 .`

Or run `./build-images.sh`. 

You can filter by language, i.e. `./build-images.sh --filter=ada`

You can perform a dry run, i.e. `./build-images.sh --filter=ada --dry-run`

### Pruning builder cache

`docker builder prune --all --force`