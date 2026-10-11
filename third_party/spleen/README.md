# Spleen 12×24

Saltic embeds the native Spleen bitmap family as its fixed system typeface.
The generated table in `os/fonts/spleen.saltic` contains the 5×8, 6×12, 8×16,
12×24, 16×32 and 32×64 sizes with ASCII (`U+0020–U+007E`) and Russian Cyrillic
(`Ё`, `А–я`, `ё`). Markdown heading levels are the only public size protocol.

- Font: Spleen 2.0.2
- Author: Frederic Cambus
- Cyrillic work: Nikolay Nazarov (`nerfur`)
- Source: <https://github.com/nerfur/spleen/tree/80ebf3d45cb7f79a20099fc50492fd7d9ac0a626>
- Cyrillic contribution: <https://github.com/fcambus/spleen/pull/38>
- License: BSD-2-Clause; see `LICENSE` in this directory.

Source SHA-256 checksums:

```text
82cc0999375b5b4cb407eabb625e535d41e02805dbb5e5566385d701eca2a0f6  spleen-5x8.bdf
107785a85e7018c299e651d2030e9356b102de2099d7a903f3e5f4e748ba52cf  spleen-6x12.bdf
71ae24a2c030529e497717fe06598ed34f13fb4777759b6e8bea3d1129dc4fa3  spleen-8x16.bdf
8c004e16e2d1d607197d3ab91eb82382a26edb93aa102adf1597f62e38fd5740  spleen-12x24.bdf
56fc3e4b1c4c25b43a2e596af606211072f21c257997f37e38ccc10f7f15e1ff  spleen-16x32.bdf
517aa3f867a923b67134b84aaf40d212a0046c94fe1d27060872936f4352ad39  spleen-32x64.bdf
```

Regenerate the embedded table:

```sh
for size in 5x8 6x12 8x16 12x24 16x32 32x64; do
    curl -fsSL "https://raw.githubusercontent.com/nerfur/spleen/80ebf3d45cb7f79a20099fc50492fd7d9ac0a626/spleen-${size}.bdf" -o "/tmp/spleen-${size}.bdf"
done
node toolbox/generate-spleen.mjs os/fonts/spleen.saltic /tmp/spleen-{5x8,6x12,8x16,12x24,16x32,32x64}.bdf
```
