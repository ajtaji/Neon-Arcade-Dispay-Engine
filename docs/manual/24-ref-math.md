# GlMath.pbi

Collision tests and a curve (chapter 10 is the guide). Every test returns `#True` or `#False` as a byte and changes nothing.

Internal: `ProjectPolygon`

### CheckCollisionAABB

`#True` when two axis-aligned boxes overlap. Each box is its top-left corner (`x1`, `y1` and `x2`, `y2`) and its size (`w1`, `h1` and `w2`, `h2`). The comparisons are strict: boxes that only touch do not overlap.

### CheckCollisionCircle

`#True` when two circles (centres `x1`, `y1` and `x2`, `y2`; radii `Radius1`, `Radius2`) overlap or touch: the squared distance between the centres is at most the squared sum of the radii.

### CheckCollisionPixelPerfect

`#True` when a solid pixel of one sprite's alpha mask lies on a solid pixel of the other's, each placed as `DrawGLSprite` would draw it: top-left `X`, `Y`, turned by `Angle` radians about its centre, sized by `Scale`. A sprite of 0 gives `#False`. Both sprites need an alpha mask: the test reads it without checking, so a sprite without one (a render target's) makes it read from address 0. The test first rejects sprites whose circles (radius half the longer side, about the centre) do not meet, then walks the whole screen pixels within the first sprite's longer side of its top-left corner (chapter 10 gives the limit this sets for turned sprites).

### GenerateSpriteHull

The convex hull of a sprite's solid pixels, as a new `GLPolygon`, its points measured from the sprite's centre (gift wrapping; points along an edge can be kept). 0 for a sprite without a mask or with fewer than three solid pixels. The program frees the polygon.

### Math_CrossProduct

`(Ax - Ox) * (By - Oy) - (Ay - Oy) * (Bx - Ox)`: positive when O, A, B turn counter-clockwise in a y-up system (clockwise on the screen), negative the other way, 0 in line.

### CheckCollisionSAT

`#True` when two convex polygons, moved by their offsets (`OffsetAX`, `OffsetAY` and `OffsetBX`, `OffsetBY`), overlap: no edge normal of either polygon separates their projections. Polygons that touch count as overlapping. A polygon of 0 gives `#False`.

### Math_CalculateBezierCubic

The point at `t` (0 to 1) of the cubic Bezier curve with control points `p0` to `p3`, into `*OutX`, `*OutY`.

### CheckCollisionLineLine

`#True` when the segments (`x1`, `y1`)-(`x2`, `y2`) and (`x3`, `y3`)-(`x4`, `y4`) cross at a point strictly inside both; the point goes to `*OutX`, `*OutY` when they are given. Parallel segments, and segments that meet only at an end, give `#False`.

### CheckCollisionLineCircle

`#True` when the segment comes within `r` of the centre `cx`, `cy` (touching counts). A segment of zero length is tested as a point.
