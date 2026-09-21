; ============================================================================
; GlTypes.pbi - Core Engine Data Structures
; ============================================================================

; --- Math & Collision Structures ---
Structure GLPoint
  x.f
  y.f
EndStructure

Structure GLPolygon
  VertexCount.i
  *Vertices.GLPoint
EndStructure

; --- Graphics & Sprite Structures ---
Structure GLSprite
  TextureID.l
  Width.i
  Height.i
  *AlphaMask
  *CollisionPoly.GLPolygon  ; <--- Strongly typed now! No more generic pointers.
EndStructure

Structure GLAnimation
  *Sprite.GLSprite
  FrameW.f : FrameH.f
  TotalFrames.i
  Columns.i
  Speed.f
  CurrentTime.f
EndStructure

; --- UI Framework Structures ---
Prototype NeonEventCallback(GadgetID.i, EventType.i)

Structure NeonGadget
  ID.i
  Type.i
  Style.i
  X.f : Y.f 
  W.f : H.f
  IsHovered.b
  IsFocused.b
  SubFocus.i
  IsActive.i     
  Value.f        
  Text.s
  FocusPulse.f
  HoverAlpha.f
  *Callback.NeonEventCallback
  *Font
EndStructure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 51
; FirstLine = 6
; EnableXP
; DPIAware