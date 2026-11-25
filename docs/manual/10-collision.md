# Collision and maths

`GlMath.pbi` holds the engine's collision tests and one curve. It needs only `GlTypes.pbi`, so it works in a program with no window. Every test returns `#True` or `#False` and changes nothing. All coordinates are whatever units the program uses, normally world or canvas units.

## The tests

| Test | Overlap when | Touching edges |
|---|---|---|
| `CheckCollisionAABB(x1, y1, w1, h1, x2, y2, w2, h2)` | two axis-aligned boxes, each by its top-left corner and size, share area | do **not** overlap |
| `CheckCollisionCircle(x1, y1, r1, x2, y2, r2)` | the centres are no further apart than the sum of the radii | **do** overlap |
| `CheckCollisionLineLine(x1, y1, x2, y2, x3, y3, x4, y4, *X, *Y)` | the segments cross strictly inside both; the crossing point goes to `*X`, `*Y` when they are given | do not (an end on the other segment, or parallel segments, is no crossing) |
| `CheckCollisionLineCircle(x1, y1, x2, y2, cx, cy, r)` | the point of the segment nearest the centre is within `r` | do |
| `CheckCollisionSAT(*PolyA, AX, AY, *PolyB, BX, BY)` | two convex polygons, each moved by its offset, overlap on every axis (the separating-axis test, on the edge normals of both) | do |
| `CheckCollisionPixelPerfect(*S1, X1, Y1, Angle1, Scale1, *S2, X2, Y2, Angle2, Scale2)` | a solid pixel of one sprite's alpha mask lies on a solid pixel of the other's, each sprite placed, turned and scaled as `DrawGLSprite` would draw it | - |

The tile-map queries of chapter 8 follow the same shape and add the cells touched.

## Polygons

A `GLPolygon` is a vertex count and a pointer to that many `GLPoint` (x, y as floats), in order round the outline. `CheckCollisionSAT` needs them convex.

`GenerateSpriteHull(*Sprite)` makes the convex hull of a sprite's solid pixels, by gift wrapping. The points are the solid pixels' coordinates measured from the sprite's centre (`x - Width / 2`, `y - Height / 2`), so the polygon turns about the same point the sprite does. Points that lie along a straight edge of the hull can be kept as vertices. A sprite with fewer than three solid pixels gives 0. The polygon is the program's to free (chapter 4).

`Math_CrossProduct(Ox, Oy, Ax, Ay, Bx, By)` is the cross product of `A - O` and `B - O`: its sign says which way the turn from `O` to `A` to `B` goes (positive is counter-clockwise with y upwards, which is clockwise on the screen, where y grows downwards), and zero that the three points are in line.

## Pixel masks

`CheckCollisionPixelPerfect` first rejects two sprites whose circles, of a radius half the longer side of each, do not meet; it then walks the screen pixels round the first sprite and, for each solid pixel of its mask, looks up the same screen pixel in the second sprite's mask. Each sprite needs an alpha mask: one loaded by `LoadGLSprite`, or a `GLSprite` with only `Width`, `Height` and `AlphaMask` filled in, as in the example below.

> Two limits come from the arithmetic as written. The first test uses half the longer side, not half the diagonal, as each sprite's radius; and the pixels walked are those within the longer side of the first sprite's top-left corner, not of its centre. A sprite turned so that a corner reaches further than that can overlap another there without the test finding it. For sprites turned through large angles, a hull and `CheckCollisionSAT` cover the whole outline.

## A Bezier curve

`Math_CalculateBezierCubic(t, p0x, p0y, p1x, p1y, p2x, p2y, p3x, p3y, *X, *Y)` puts the point of the cubic Bezier curve with control points `p0` to `p3` at `t` (0 at `p0`, 1 at `p3`) in `*X`, `*Y`.

## A worked example

@include examples/collision.pb

It prints:

@include examples/output/collision.txt
