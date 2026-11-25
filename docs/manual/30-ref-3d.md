# Gl3D.pbi and its companions

The 3D renderer (chapter 13 is the guide): `Gl3D.pbi` includes `Gl3DMath.pbi`, `Gl3DLoader.pbi`, `Gl3DAnimation.pbi`, `Gl3DRender.pbi` and `Gl3DMesh.pbi`. A procedure that cannot do what it is asked returns 0 (or does nothing) and leaves the reason in `G3D_Error()`.

## Constants

- `#G3D_MaxFile` - 268435456 (256 MB), the largest `.glb` file read; `#G3D_MaxNodes` - 4096, the most nodes.
- `#G3D_Translation`, `#G3D_Rotation`, `#G3D_Scale` (0, 1, 2) - what an animation track moves, in `G3DTrack\path`.
- `#G3D_Linear`, `#G3D_Step`, `#G3D_Cubic` (0, 1, 2) - how a track interpolates, in `G3DTrack\mode`.

## Structures

### Structure G3DMatrix

A 4 by 4 matrix, 16 floats in column-major order (`v[12]`, `v[13]`, `v[14]` the translation).

### Structure G3DPose

A node's local place: translation `p[]`, rotation `q[]` as a quaternion x, y, z, w (glTF's order), scale `s[]`.

### Structure G3DCamera

What a draw needs of the camera: `viewProjection` and the `eye` position.

### Structure G3DMaterial

A surface: `color[]` (red, green, blue, alpha, 0 to 1; alpha is not used: models are opaque), `emission[]` (light it gives, added), `metal` and `rough` (0 to 1), `twoSided` (back faces drawn too).

### Structure G3DModel

A model. A program sets `transform`, the model's place in the scene (identity when made). Read: `nodes()`, `skins()`, `materials()`, `primitives()`, `clips()`, the clip playing (`active`) and the one fading out (`outgoing`), the times and fade (`time`, `outgoingTime`, `fade`, `fadeTime`), `vertices` (the vertex count), `procedural` (made by `G3D_Mesh`), and `context` (the `GLWindowContext` it belongs to).

### Structure G3DNode

A node of a model: `name`, `parent` (-1 for a root), `mesh` and `skin` (-1 for none), `visible` (in the default scene), `hasMatrix` (placed by a matrix, `local`, rather than by a pose), its poses (`rest`, `pose`, `fadePose`), its `world` matrix, and its spring (`spring`, `stiffness`, `damping`, `gravity` and the spring's moving state).

### Structure G3DPrimitive

A drawn piece of a model: its vertex array and buffers (`vao`, `vbo`, `ebo`; `ebo` 0 when not indexed), `count` vertices or indices, its `node` and `material`.

### Structure G3DSkin

A skin: its joints (`joint()`, each a node and its inverse bind matrix, `G3DJoint`), the joint matrices of the last draw (`palette()`), and the texture they go to the GPU in.

### Structure G3DJoint

A joint of a skin: its `node` and `inverseBind` matrix.

### Structure G3DClip

An animation clip: `name`, `duration` in seconds, its `tracks()`.

### Structure G3DTrack

One animated property of one node: `node`, `path` (`#G3D_Translation` ...), `mode` (`#G3D_Linear` ...), `width` (3 or 4 values a key), `count` keys, their `times()` in seconds and `values()`.

### Structure G3DPass

The 3D pass on the canvas: its context, the canvas framebuffer and its depth buffer, the canvas size at `G3D_Init`, the shader and its uniforms, and the OpenGL state `G3D_Begin` saved. A program reads nothing in it.

Internal: `G3DAccess`, `G3DReader`, `G3DVertex`

## Errors

### G3D_Error

The sentence that says why the last refused 3D call was refused.

## Maths

### G3D_Identity

Sets `*m` to the identity matrix.

### G3D_Transform

Sets `*m` to a translation (`x`, `y`, `z`), a turn of `yaw` radians about the y axis, and a uniform `scale` (1 by default).

### G3D_LookAt

Fills `*camera` for an eye at `x`, `y`, `z` looking at `tx`, `ty`, `tz`, with the up direction `upX`, `upY`, `upZ` (0, 1, 0): a right-handed view and an OpenGL perspective of full vertical angle `fov` radians (0.85), `aspect` width over height, clipping at `near` (0.05) and `far` (150). Returns `#True`, or `#False` without changing the camera when `aspect` or `near` is 0 or less, `far` is not beyond `near`, `fov` is not between 0 and pi, the eye is on its target, or the up direction lies along the line of sight. No error sentence.

## The pass

### G3D_Init

Sets up a pass on the canvas: a 24-bit depth buffer of `Util_BaseWidth` by `Util_BaseHeight` attached to `Util_FBO`, and the shader, into which `geometryProjection` (GLSL defining `void projectVertex(inout vec3 point, inout vec3 normal)`, or "") is compiled. Returns 1. Refused: a pass already set up, no canvas framebuffer, no current `GLWindowContext`, OpenGL older than 3.3, a canvas that already has a depth buffer or does not accept one.

### G3D_Begin

Begins drawing in the pass: saves the program, vertex array, texture, depth and blend, cull and scissor state; turns blending and the scissor off, the depth test on (less than); clears the depth buffer. Returns 1. Refused: a pass not set up, another context current, another pass begun, a canvas framebuffer or size that changed since `G3D_Init`, or the canvas framebuffer not bound.

### G3D_SetProjection

Sets the four `projectionParams` the custom `projectVertex` reads, while the pass is begun.

### G3D_Draw

Draws a model with a camera, while the pass is begun: updates and uploads each skin's joint matrices, then draws each primitive with its node's world matrix times the model's `transform` (a skinned primitive: the `transform` alone, the skeleton being in the joint matrices), its material, and back faces skipped unless two-sided. Returns 1; refused when there is no pass begun, no model or camera, the model belongs to another context, or OpenGL reports an error.

### G3D_End

Ends the pass begun: puts back what `G3D_Begin` saved.

### G3D_Shutdown

Ends the pass if it is begun, takes its depth buffer off the canvas, frees it and the shader, and clears the structure. Nothing when the pass is not set up or another context is current.

## Models

### G3D_Mesh

Uploads `count` vertices from `*vertices` (each six floats: position x, y, z, normal x, y, z; three a triangle) with `*material` (copied). With `*m` 0 it makes a new model and returns it; given a model it made before in the same context, it replaces that model's triangles and returns it. Refused: no vertices or material, a count below 3, not a multiple of 3, or above 4,000,000, a model not made by `G3D_Mesh` or of another context, an upload OpenGL refuses.

### G3D_Load

Reads a glTF 2.0 binary file (`path`) into a new model (appendix A lists what it accepts), makes spring bones of the nodes whose names start with `breast.`, `glute.`, `bust.` or `hip.` (in any case), and poses it once. Returns the model, or 0 with a sentence.

### G3D_Free

Frees a model's buffers and textures and the model. Refused, and nothing freed, when another context is current.

## Animation

### G3D_Play

Starts clip `clip` from its beginning, crossfading from the present pose over `blend` seconds (0.2 by default; 0 cuts). When no fade is going on, the clip that was playing keeps moving while it fades out; when one is, the fade starts from the pose held at that moment. Returns 1; refused for a negative or invalid `blend` or a clip the model does not have.

### G3D_Update

Moves the model on by `seconds` (at most 0.1 at a time): the clip playing (looping), the crossfade, the world matrices of every node (parents first), and the spring bones (integrated in steps of at most 1/120 s). Returns 1; refused for a negative or invalid time. Call it once a frame, before `G3D_Draw`.

### G3D_Spring

Makes node `bone` a spring bone with `stiffness` (1 to 1000; 60), `damping` (0 to 100; 12) and `gravity` (-100 to 100; 1.1, pulling down the y axis). Refused: values out of range, no node of that name, a node placed by a matrix.

### G3D_Impulse

Adds the velocity `x`, `y`, `z` (scene units a second) to every spring bone of the model. Invalid numbers are ignored.
