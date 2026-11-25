@appendix
# File formats

The engine reads and writes two files of its own, and reads one standard format. Every number in the engine's own files is **big-endian** (the most significant byte first), so the cells and colours can be used where they lie by hardware that reads them that way.

## The chunked layout

Both of the engine's files share one layout: an 8-byte header, then chunks.

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | the file's mark: `NTMP` (a tile map file) or `NTIX` (an indexed image or palette file), ASCII |
| 4 | 2 | the version: 1 |
| 6 | 2 | the number of chunks that follow |

Each chunk:

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | the chunk's id, four ASCII characters (a space pads a short one: `"MAP "`) |
| 4 | 4 | the payload's length in bytes |
| 8 | length | the payload |
| 8 + length | 0 to 3 | zero bytes, to the next multiple of 4 |

A reader skips a chunk whose id it does not know. A file whose mark or version is not these is refused, and so is a chunk that runs past the end of the file.

## The tile map file (.ntm)

| Chunk | Payload |
|---|---|
| `MAP ` | width (2), height (2), tile width (2), tile height (2), then width x height cells of 2 bytes each, row 0 first, left to right. One chunk per tile layer, back to front. |
| `ANIM` | the number of animated tiles (2); for each: the tile (2), its number of frames (2), then for each frame its tile (2) and its time in milliseconds (2) |
| `TFLG` | the number of tiles in the set (2), then one collision byte per tile |
| `TPAL` | the number of tiles in the set (2), then one palette slot per tile (an indexed set) |

A cell is the 16-bit word of chapter 7:

| Bits | Meaning |
|---|---|
| 0 to 11 | the tile number + 1; 0 is an empty cell |
| 12 | diagonal flip (`#GL_TILE_DIAG`) |
| 13 | reserved, 0 |
| 14 | left-right mirror (`#GL_TILE_FLIPX`) |
| 15 | top-bottom mirror (`#GL_TILE_FLIPY`) |

`GL_TileMapSave` writes one `MAP ` chunk, then, when the set is saved with it, `ANIM` if any tile is animated, `TFLG` if any tile has a collision byte, and `TPAL` if any tile of an indexed set uses a slot other than 0. `GL_TileMapLoad` requires the layer's length to be exactly 8 + width x height x 2 and its tile size to be the set's. `GL_TileSetLoad` requires `TFLG` and `TPAL` to be for a set of the same number of tiles, and clears a table the file does not hold.

For example, the 20 by 10 map of chapter 7's example, with its animation and two collision bytes, is a header (8 bytes), a `MAP ` chunk (8 + 408 bytes), an `ANIM` chunk (8 + 14, padded to 16) and a `TFLG` chunk (8 + 34, padded to 36): 492 bytes.

## The indexed image file (.nti)

| Chunk | Payload |
|---|---|
| `IDX8` | width (2), height (2), then width x height bytes, one a pixel, row 0 first |
| `IDX4` | width (2), height (2), then two pixels a byte, the first in the high four bits; each row starts on a new byte, so a row is (width + 1) / 2 bytes, rounded down |
| `PAL ` | the slot (1, 0 to 7), 0 (1), the number of colours (2, 1 to 256), then each colour as 4 bytes: red, green, blue, alpha |

A file holds at most one image chunk and at most one palette a slot. A **palette file** is the same file with no image chunk; `GL_PaletteSave` writes its palette as slot 0. `GL_IndexedSave` writes the image chunk, then a `PAL ` chunk for each slot that holds a palette, with that palette's `Count` colours as set (not as shown). A damaged file - a length that does not match its width and height, a second image chunk, a slot above 7, a colour count out of range - is refused as a whole.

## The glTF binary file (.glb), as `G3D_Load` reads it

`G3D_Load` reads glTF 2.0 in its binary container. These are the rules it checks; a file that breaks one is refused with a sentence that names it.

**The container.** The file is 28 bytes to 256 MB. It starts with the mark `glTF` (the 32-bit little-endian value $46546C67), version 2 and the file's length; then chunks of a 32-bit length (a multiple of 4) and a 32-bit type, the first a JSON chunk (type `JSON`) right after the header, then exactly one binary chunk (type `BIN`). The chunks fill the file exactly.

**The JSON.** `asset.version` is "2.0". `extensionsRequired` may name only `KHR_materials_emissive_strength`. There is one buffer, with no `uri` (it is the binary chunk), whose `byteLength` is within the chunk and at most 3 bytes short of it.

**Accessors.** Of type `SCALAR`, `VEC2`, `VEC3`, `VEC4` or `MAT4`, components of unsigned byte, unsigned short, unsigned int or float; not sparse; their buffer view in buffer 0; a stride of at most 252 bytes; aligned to their component size; within their view.

**Nodes.** 1 to 4096. Each placed by `matrix`, or by `translation`, `rotation` and `scale` (a rotation must be within 0.02 of unit length; it is normalised). Every child has one parent and the graph has no cycle. The default scene (`scene`, or scene 0) has roots, and only the nodes under them are drawn.

**Materials.** Factors only: `baseColorFactor`, `metallicFactor` (1 when absent), `roughnessFactor` (1), `emissiveFactor`, multiplied by `KHR_materials_emissive_strength`'s `emissiveStrength`, and `doubleSided`. Any texture (base colour, metallic-roughness, normal, occlusion, emissive), or an `alphaMode` other than `OPAQUE`, is refused. A primitive without a material gets a white one, metallic and rough.

**Primitives.** Triangles only (`mode` 4), no morph targets, no second set of joints and weights. `POSITION` and `NORMAL` are float `VEC3` of the same count, at most 4,000,000 vertices. Indices, when present, are integers (no float, not normalised), at most 12,000,000, a multiple of 3, each below the vertex count. With a skin: `JOINTS_0` of unsigned bytes or shorts (not normalised), each below the skin's joint count; `WEIGHTS_0` of floats, or of normalised unsigned bytes or shorts, each 0 to 1 and not all 0 (they are scaled to add up to 1). Positions, normals and weights must be finite numbers.

**Skins.** 1 to 65536 joints, and no more than the GPU's largest texture size; `inverseBindMatrices`, when present, float `MAT4`, at least one a joint, finite.

**Animations.** Each channel targets a node placed by translation, rotation and scale (not a matrix), and its `translation`, `rotation` or `scale` (not morph weights). Interpolation `LINEAR` (also when absent), `STEP` or `CUBICSPLINE`. Times are float, at least 0, strictly increasing, at most 100,000 keys; values are float `VEC3` (or `VEC4` for rotation), one a key (three for cubic splines: in-tangent, value, out-tangent), finite, rotations within 0.02 of unit length (normalised). A clip lasts as long as its last key.
