# Installation
First, install [Zig](https://ziglang.org) if you have not already.

Then, clone this repository: ``git clone https://github.com/Vescusia/vesclomacy.git``

Compile it: ``cd vesclomacy && zig build --release=safe``

The binary will be in `zig-out/bin/`.

# Usage
## Create a file containing the moves your players want to make
An example of the format:
```text
# This is a comment

# This is a Move from the province 'spa' to the province 'gas':
spa move gas

# This is a Hold in the province 'gas':
gas hold

# This is a Support for 'spa', trying to move to 'gas', from the province 'mar':
mar supp spa

# This is a Convoy from the province 'por' to the province 'bre', through the sea 'mid'
por move bre
mid conv por bre

# Order of operations does *not* matter
# Any Province Name is valid (misspells included!)
# Inline comments are not allowed
```

## Solve the Dependencies and see which Moves are allowed to happen
> ./zig-out/bin/vesclomacy example-moves.txt
```text
info: Opening file 'example-moves.txt'

IN:
  spa move gas
  mid conv (por move bre)
  mar supp spa
  por move bre
  gas hold

OUT:
  [DONE] spa move gas
  [DONE] mid conv (por move bre)
  [DONE] mar supp spa
  [DONE] por move bre
  [FLEE] gas by   spa
```
