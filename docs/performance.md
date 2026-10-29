# Performance

How much a frame costs in each region, measured with the `perf_survey` playtest:

```bash
scripts/playtest.sh perf_survey --render --out /tmp/perf
```

It stands at a spot in each region and averages Godot's monitors over 30 frames. Draw calls, objects and primitives (triangles) only mean something with `--render`. The development machine renders in software (llvmpipe), so its script and frame times aren't comparable with a real GPU and aren't recorded here. The counts are.

## 2026-10-28 (#291)

Before: every mesh in the world was drawn every frame, out to a 400 m far plane, though depth fog hides everything beyond 150 m. After: the far plane is 170 m, and `scripts/world/visibility_ranges.gd` stops drawing small meshes far away, by size. Meshes under 1 m across in radius stop at 70 m, under 3 m at 100 m, and under 8 m at 140 m. Larger ones (walls, buildings, terrain) always draw, and meshes that set their own range (labels, grass) keep it.

| Spot | Draw calls before | after | Objects before | after | Triangles before | after |
|---|---|---|---|---|---|---|
| Fort forum | 1,018 | 1,009 | 1,755 | 1,711 | 648k | 646k |
| Fort fields | 812 | 824 | 1,587 | 1,590 | 584k | 589k |
| Grove | 492 | 486 | 1,126 | 1,103 | 398k | 398k |
| Portus Salis | 306 | 299 | 804 | 786 | 286k | 284k |
| Frontier camp | 741 | 315 | 1,562 | 1,179 | 533k | 370k |
| Vipasca | | 221 | | 784 | | 317k |
| Seriphos town | | 165 | | 653 | | 246k |
| Circus | | 82 | | 439 | | 177k |
| Villa | | 96 | | 414 | | 115k |

(The first run timed out after the frontier.)

Where the triangles are, across the whole scene: monsters 287k in 871 meshes (creatures are built from separately animated parts), Castra Ferrea's dressing 212k in 770, then each region's 110k to 170k. The fort is the busiest place because nearly everything in it is within range of the forum. Around 1,000 draw calls is comfortable for a desktop GPU but heavy for integrated graphics.

If the fort is slow on real hardware, the next steps are:

- Merge each static Kenney prop's parts into one mesh per material when dressing. Most props are several meshes.
- Use multimeshes for repeated props: fences, palisade stakes, barrels.
- Lower the Low preset's shadow distance further (it is 40 m now).

The HUD's top line shows frames per second. An F8 note from the fort with the FPS in it is the most useful measurement.
