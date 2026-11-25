# The OpenGL bindings

Four files give PureBasic the OpenGL interface. `GlUtilities.pbi` includes them; a program does not include them itself. They were generated from the OpenGL registry and hold the API's own names, which are documented by the OpenGL specification, not here.

| File | Holds |
|---|---|
| `opengl_constants.pbi` | about 6000 constants, `#GL_...` with the registry's values (`#GL_TEXTURE_2D`, `#GL_FRAMEBUFFER` ...) |
| `opengl_features.pbi` | a constant set to 1 for each OpenGL and OpenGL ES version the bindings cover (`#GL_VERSION_1_0` to `#GL_VERSION_4_6`, `#GL_ES_VERSION_2_0` ...) |
| `opengl_extensions.pbi` | a constant set to 1 for each extension in the registry (`#GL_ARB_...`, `#GL_EXT_...`, and the vendors') |
| `opengl_prototypes.pbi` | about 3300 function prototypes, `PrototypeC glName(...)`, the shape of every OpenGL function |

Each constant is defined only if it is not defined already (`CompilerIf Not Defined(...)`), so a program, or PureBasic itself, may define it first. A prototype is a type, not a function: to call an OpenGL function that is not in OpenGL 1.1, a program declares a variable of its prototype and fills it with `GetGLProc`:

```pb
Global MyDeleteProgram.glDeleteProgram = GetGLProc("glDeleteProgram")   ; after a context is current
```

PureBasic's own OpenGL library provides the OpenGL 1.1 functions with a trailing underscore (`glClear_`, `glViewport_`, `glBindTexture_` ...); the engine uses those for everything OpenGL 1.1 has.

## The entry points the engine loads

`LoadModernGL` fills these globals, each of the prototype of the same name, with the driver's functions; once a window is open a program may call them like any procedure: `glGenVertexArrays`, `glBindVertexArray`, `glGenBuffers`, `glBindBuffer`, `glBufferData`, `glBufferSubData`, `glCreateShader`, `glShaderSource`, `glCompileShader`, `glGetShaderiv`, `glGetShaderInfoLog`, `glCreateProgram`, `glAttachShader`, `glLinkProgram`, `glGetProgramiv`, `glGetProgramInfoLog`, `glUseProgram`, `glVertexAttribPointer`, `glEnableVertexAttribArray`, `glDeleteShader`, `glGetUniformLocation`, `glUniform1f`, `glUniform2f`, `glUniform3f`, `glUniform4f`, `glUniform1i`, `glActiveTexture`, `glGenFramebuffers`, `glBindFramebuffer`, `glFramebufferTexture2D`, `glCheckFramebufferStatus`, `glDrawArraysInstanced`, `glVertexAttribDivisor`, and on Windows `wglSwapIntervalEXT` and `wglGetSwapIntervalEXT`. On Linux the engine also imports `glXGetProcAddressARB` from `libGL`.

The prototypes of `glGenFramebuffers`, `glBindFramebuffer`, `glFramebufferTexture2D`, `glCheckFramebufferStatus`, `glDrawArraysInstanced`, `glVertexAttribDivisor`, `glUniform2f` and `glUniform3f` are declared in `GlUtilities.pbi` itself, under names ending in `_Type`.

Internal: `glGenFramebuffers_Type`, `glBindFramebuffer_Type`, `glFramebufferTexture2D_Type`, `glCheckFramebufferStatus_Type`, `glDrawArraysInstanced_Type`, `glVertexAttribDivisor_Type`, `glUniform2f_Type`, `glUniform3f_Type`, `wglSwapIntervalEXT`, `wglGetSwapIntervalEXT`
