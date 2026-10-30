# Library cores: encoders

Link-layer, 8b/10b and framing blocks.

Each core is its own FuseSoC core (`qick:encoders:<name>:<version>`, the version is in the `name:` of its `.core` file); the RTL is in `firmware/rtl_lib/` and `hdl/` links to it.
Simulate one with `make sim IP=<name>`, lint it with `make lint IP=<name>`. How to create a core: [NEW_CORE.md](../../../../docs/developer/NEW_CORE.md).

| Core | What it is | Tests |
|---|---|---|
| [`bin2gray`](bin2gray/) | Binary to Gray code converter | yes |
| [`enc_8b10b`](enc_8b10b/) | IBM 8b/10b line encoder (single lane), registered output, RD tracked internally | yes |
| [`priority_encoder`](priority_encoder/) | priority_encoder (encoders library core) | yes |

3 cores. The list is checked by `make doc-check`: a core added here must be added to this table.
