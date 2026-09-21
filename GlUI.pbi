; ============================================================================
; GlUI.pbi - NeonArcade Direct OpenGL UI Framework
; ============================================================================

;   Framework Constants  
#NEON_BASE_W = 1280.0
#NEON_BASE_H = 720.0

Enumeration NeonGadgetTypes
  #NEON_BUTTON
  #NEON_CHECKBOX
  #NEON_SLIDER
  #NEON_TOGGLE
  #NEON_METER
  #NEON_LABEL
  #NEON_BREADCRUMB 
  #NEON_DIPBANK
  #NEON_CAROUSEL
EndEnumeration

Enumeration NeonStyles
  #STYLE_CLASSIC
  #STYLE_MODERN
  #STYLE_GLOW
EndEnumeration



Global UI_UseCRT.b = #True
Global NewList UI_Gadgets.NeonGadget()
Global UI_ActiveFont.i 
Global UI_FocusIndex.i = 0 
Global UI_MouseX.f = 0.0  
Global UI_MouseY.f = 0.0

; ============================================================================
; VIRTUAL MAPPING & GADGET CREATION
; ============================================================================

Procedure MapPhysicalToVirtual(PhysX.i, PhysY.i, *VirtX.Float, *VirtY.Float)
  
  ;   THE LINUX GTK3 SCALING FIX  
  ; Convert logical OS mouse coordinates to physical OpenGL viewport coordinates
  CompilerIf #PB_Compiler_OS = #PB_OS_Linux
    PhysX = PhysX * Linux_DPIScale
    PhysY = PhysY * Linux_DPIScale
  CompilerEndIf
  
  ; dynamically pull the base canvas size from the global state
  Define ScaleX.f = GL_ViewportW / Util_BaseWidth
  Define ScaleY.f = GL_ViewportH / Util_BaseHeight
  
  Define AdjustedX.f = PhysX - GL_ViewportX
  Define AdjustedY.f = PhysY - GL_ViewportY
  
  *VirtX\f = AdjustedX / ScaleX
  *VirtY\f = AdjustedY / ScaleY
  
  If UI_UseCRT
    Define NdcX.f = (*VirtX\f / Util_BaseWidth) * 2.0 - 1.0
    Define NdcY.f = (*VirtY\f / Util_BaseHeight) * 2.0 - 1.0
    Define DotProd.f = (NdcX * NdcX) + (NdcY * NdcY)
  
    NdcX = NdcX + (NdcX * DotProd * 0.015)
    NdcY = NdcY + (NdcY * DotProd * 0.015)
    *VirtX\f = ((NdcX * 0.5) + 0.5) * Util_BaseWidth
    *VirtY\f = ((NdcY * 0.5) + 0.5) * Util_BaseHeight
  EndIf
EndProcedure

Procedure.i Neon_AddCarousel(ID.i, X.f, Y.f, W.f, H.f, Options.s, InitialIndex.i = 0, *Callback = 0)
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_CAROUSEL
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = W : UI_Gadgets()\H = H 
  UI_Gadgets()\Text = Options : UI_Gadgets()\Value = InitialIndex : UI_Gadgets()\Callback = *Callback
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

Procedure.i Neon_AddLabel(ID.i, X.f, Y.f, Text.s)
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_LABEL
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = 0 : UI_Gadgets()\H = 0 : UI_Gadgets()\Text = Text
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

Procedure.i Neon_AddBreadcrumb(ID.i, X.f, Y.f, Text.s)
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_BREADCRUMB
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = 0 : UI_Gadgets()\H = 0 : UI_Gadgets()\Text = Text
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

Procedure.i Neon_AddButton(ID.i, X.f, Y.f, W.f, H.f, Text.s, Style.i = #STYLE_MODERN, *Callback = 0)
  If UI_ActiveFont
    Define TW.f = GetGLTextWidth(UI_ActiveFont, Text)
    If W < (TW + 40.0) 
      Define OldW.f = W
      W = TW + 40.0 
      X = X - ((W - OldW) / 2.0) 
    EndIf
  EndIf
  
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_BUTTON : UI_Gadgets()\Style = Style
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = W : UI_Gadgets()\H = H : UI_Gadgets()\Text = Text : UI_Gadgets()\Callback = *Callback
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

Procedure.i Neon_AddSlider(ID.i, X.f, Y.f, W.f, H.f, InitialValue.f, Text.s = "", *Callback = 0)
  If UI_ActiveFont And Text <> ""
    Define TW.f = GetGLTextWidth(UI_ActiveFont, Text)
    If W < TW
      Define OldW.f = W
      W = TW
      X = X - ((W - OldW) / 2.0)
    EndIf
  EndIf
  
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_SLIDER
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = W : UI_Gadgets()\H = H : UI_Gadgets()\Value = InitialValue : UI_Gadgets()\Text = Text : UI_Gadgets()\Callback = *Callback
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

Procedure.i Neon_AddToggle(ID.i, X.f, Y.f, W.f, H.f, Text.s, InitialState.i = 0, *Callback = 0)
  If UI_ActiveFont
    Define TW.f = GetGLTextWidth(UI_ActiveFont, Text)
    If W < (TW + 80.0) 
      Define OldW.f = W
      W = TW + 80.0 
      X = X - ((W - OldW) / 2.0) 
    EndIf
  EndIf
  
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_TOGGLE
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = W : UI_Gadgets()\H = H : UI_Gadgets()\Text = Text : UI_Gadgets()\IsActive = InitialState : UI_Gadgets()\Callback = *Callback
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

Procedure.i Neon_AddMeter(ID.i, X.f, Y.f, W.f, H.f, InitialValue.f, Text.s)
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_METER
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = W : UI_Gadgets()\H = H : UI_Gadgets()\Text = Text : UI_Gadgets()\Value = InitialValue
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

Procedure.i Neon_AddDipBank(ID.i, X.f, Y.f, SwitchCount.i, InitialBitmask.i, Text.s, *Callback = 0)
  Define BankW.f = (SwitchCount * 40.0) + 20.0
  Define H.f = 70.0
  
  If UI_ActiveFont
    Define TW.f = GetGLTextWidth(UI_ActiveFont, Text)
    If BankW < TW
      Define OldW.f = BankW
      BankW = TW
      X = X - ((BankW - OldW) / 2.0)
    EndIf
  EndIf
  
  AddElement(UI_Gadgets()) : UI_Gadgets()\ID = ID : UI_Gadgets()\Type = #NEON_DIPBANK
  UI_Gadgets()\X = X : UI_Gadgets()\Y = Y : UI_Gadgets()\W = BankW : UI_Gadgets()\H = H 
  UI_Gadgets()\Text = Text : UI_Gadgets()\IsActive = InitialBitmask : UI_Gadgets()\Value = SwitchCount : UI_Gadgets()\Callback = *Callback
  UI_Gadgets()\Font = UI_ActiveFont ; <--- MEMORY FIX
  ProcedureReturn @UI_Gadgets()
EndProcedure

; ============================================================================
; RENDERING PIPELINE
; ============================================================================

Procedure Neon_DrawUI(DeltaTime.f)
  Define i.i 
  ForEach UI_Gadgets()
    Define gx.f = UI_Gadgets()\X : Define gy.f = UI_Gadgets()\Y
    Define gw.f = UI_Gadgets()\W : Define gh.f = UI_Gadgets()\H
    
    If UI_Gadgets()\IsHovered Or UI_Gadgets()\IsFocused
      UI_Gadgets()\HoverAlpha + (DeltaTime * 6.0)
      If UI_Gadgets()\HoverAlpha > 1.0 : UI_Gadgets()\HoverAlpha = 1.0 : EndIf
      If UI_Gadgets()\IsFocused : UI_Gadgets()\FocusPulse + (DeltaTime * 4.0) : EndIf
    Else
      UI_Gadgets()\HoverAlpha - (DeltaTime * 6.0)
      If UI_Gadgets()\HoverAlpha < 0.0 : UI_Gadgets()\HoverAlpha = 0.0 : EndIf
      UI_Gadgets()\FocusPulse = 0.0
    EndIf
    
    ; Pull the saved font from the gadget's memory!
    Define *Fnt.GLFont = UI_Gadgets()\Font
    If Not *Fnt : *Fnt = UI_ActiveFont : EndIf 
    
    Define TH.f = 0.0 : If *Fnt : TH = *Fnt\LineHeight : EndIf
    
    Select UI_Gadgets()\Type
      
      Case #NEON_LABEL
        If *Fnt : DrawGLText(*Fnt, gx, gy, UI_Gadgets()\Text, 1.0, 0.8, 0.2, 1.0, #True, #True) : EndIf
        
      Case #NEON_BREADCRUMB
        If *Fnt
          DrawGLText(*Fnt, gx, gy, UI_Gadgets()\Text, 0.4, 0.8, 1.0, 1.0, #True, #True)
          Define BreadW.f = GetGLTextWidth(*Fnt, UI_Gadgets()\Text)
          DrawGLBox(gx, gy + TH + 4.0, BreadW, 2.0, 0.2, 0.4, 0.8, 1.0, #True, #True)
        EndIf

      Case #NEON_BUTTON
        If UI_Gadgets()\IsFocused
          DrawGLBox(gx - 4, gy - 4, gw + 8, gh + 8, 0.0, 1.0, 1.0, 0.5 + (0.5 * Sin(UI_Gadgets()\FocusPulse)), #True, #True)
        EndIf
        
        Define R.f = 0.15 + (UI_Gadgets()\HoverAlpha * 0.1)
        Define G.f = 0.25 + (UI_Gadgets()\HoverAlpha * 0.35)
        Define B.f = 0.85
        
        DrawGLBox(gx + 4, gy + 4, gw, gh, 0.0, 0.0, 0.0, 0.4, #True, #True)
        DrawGLBox(gx, gy, gw, gh, 0.4, 0.4, 0.4, 1.0, #True, #True)
        
        Define FaceR.f = 0.15 + (UI_Gadgets()\HoverAlpha * 0.2)
        DrawGLBox(gx + 2, gy + 2, gw - 4, gh - 4, FaceR, 0.2, 0.6, 1.0, #True, #True)
        
        If *Fnt
          Define TW.f = GetGLTextWidth(*Fnt, UI_Gadgets()\Text)
          DrawGLText(*Fnt, gx + (gw/2.0) - (TW/2.0), gy + (gh/2.0) - (TH/2.0), UI_Gadgets()\Text, 0.902, 0.902, 0.902, 1.0, #True, #True)
        EndIf
        
      Case #NEON_DIPBANK
        If *Fnt : DrawGLText(*Fnt, gx, gy - (TH + 6.0), UI_Gadgets()\Text, 0.8, 0.8, 0.8, 1.0, #True, #True) : EndIf
        
        DrawGLBox(gx, gy, gw, gh, 0.1, 0.1, 0.1, 1.0, #True, #True)
        DrawGLBox(gx + 4, gy + 4, gw - 8, gh - 8, 0.02, 0.02, 0.02, 1.0, #True, #True)
        
        Define SCount.i = Int(UI_Gadgets()\Value)
        Define SwitchBlockW.f = SCount * 40.0
        Define StartX.f = gx + (gw / 2.0) - (SwitchBlockW / 2.0)
        
        For i = 0 To SCount - 1
          Define sX.f = StartX + (i * 40.0)
          
          If UI_Gadgets()\IsFocused And UI_Gadgets()\SubFocus = i
            DrawGLBox(sX - 3, gy + 15.0, 26.0, 48.0, 0.0, 1.0, 1.0, 0.4 + (0.4 * Sin(UI_Gadgets()\FocusPulse)), #True, #True)
          EndIf
          
          DrawGLBox(sX + 6, gy + 6.0, 8.0, 8.0, 0.0, 0.0, 0.0, 1.0, #True, #True)
          DrawGLBox(sX, gy + 18.0, 20.0, 42.0, 0.0, 0.0, 0.0, 1.0, #True, #True) 
          
          If UI_Gadgets()\IsActive & (1 << i)
            DrawGLBox(sX + 2, gy + 20.0, 16.0, 20.0, 0.8, 0.9, 1.0, 1.0, #True, #True) 
            DrawGLPolygon(sX + 10.0, gy + 10.0, 3.0, 3.0, 16, 0.1, 1.0, 0.2, 1.0, #True, #True, #True) 
          Else
            DrawGLBox(sX + 2, gy + 38.0, 16.0, 20.0, 0.8, 0.9, 1.0, 1.0, #True, #True) 
            DrawGLPolygon(sX + 10.0, gy + 10.0, 3.0, 3.0, 16, 0.3, 0.0, 0.0, 1.0, #True, #True, #True) 
          EndIf
          
          If *Fnt
            Define NumStr.s = Str(i+1)
            Define NW.f = GetGLTextWidth(*Fnt, NumStr)
            DrawGLText(*Fnt, sX + 10.0 - (NW / 2.0), gy + gh + 5.0, NumStr, 0.5, 0.5, 0.5, 1.0, #True, #True)
          EndIf
        Next

      Case #NEON_CAROUSEL
        DrawGLBox(gx, gy, gw, gh, 0.05, 0.05, 0.05, 1.0, #True, #True)
        
        If UI_Gadgets()\IsFocused
          DrawGLBox(gx - 2, gy - 2, gw + 4, gh + 4, 0.0, 1.0, 1.0, 0.5 + (0.5 * Sin(UI_Gadgets()\FocusPulse)), #True, #True)
        EndIf
        
        If *Fnt
          Define ArrowLW.f = GetGLTextWidth(*Fnt, "<")
          Define ArrowRW.f = GetGLTextWidth(*Fnt, ">")
          
          DrawGLText(*Fnt, gx + 20.0 - (ArrowLW / 2.0), gy + (gh/2.0) - (TH/2.0), "<", 0.5, 0.5, 0.5, 1.0, #True, #True)
          DrawGLText(*Fnt, gx + gw - 20.0 - (ArrowRW / 2.0), gy + (gh/2.0) - (TH/2.0), ">", 0.5, 0.5, 0.5, 1.0, #True, #True)
          
          Define CurrentOption.i = Int(UI_Gadgets()\Value) + 1
          Define OptionText.s = StringField(UI_Gadgets()\Text, CurrentOption, "|")
          Define TW2.f = GetGLTextWidth(*Fnt, OptionText)
          DrawGLText(*Fnt, gx + (gw/2.0) - (TW2/2.0), gy + (gh/2.0) - (TH/2.0), OptionText, 0.902, 0.902, 0.902, 1.0, #True, #True)
        EndIf

      Case #NEON_TOGGLE
        If *Fnt : DrawGLText(*Fnt, gx, gy + (gh / 2.0) - (TH / 2.0), UI_Gadgets()\Text, 0.8, 0.8, 0.8, 1.0, #True, #True) : EndIf
        Define SwitchX.f = gx + gw - 60.0
        DrawGLBox(SwitchX, gy + 5.0, 60.0, gh - 10.0, 0.1, 0.1, 0.1, 1.0, #True, #True) 
        
        If UI_Gadgets()\IsActive
          DrawGLBox(SwitchX + 30.0, gy + 5.0, 30.0, gh - 10.0, 0.2, 0.9, 0.2, 1.0, #True, #True) 
          DrawGLBox(SwitchX + 30.0, gy + 5.0, 30.0, gh - 10.0, 0.6, 1.0, 0.6, 1.0, #True, #True) 
        Else
          DrawGLBox(SwitchX, gy + 5.0, 30.0, gh - 10.0, 0.8, 0.1, 0.1, 1.0, #True, #True) 
          DrawGLBox(SwitchX, gy + 5.0, 30.0, gh - 10.0, 1.0, 0.5, 0.5, 1.0, #True, #True) 
        EndIf
        
        If UI_Gadgets()\IsFocused : DrawGLBox(SwitchX - 4, gy + 1, 68.0, gh - 2.0, 0.0, 1.0, 1.0, 0.5 + (0.5 * Sin(UI_Gadgets()\FocusPulse)), #True, #True) : EndIf

      Case #NEON_METER
        If *Fnt : DrawGLText(*Fnt, gx, gy - (TH + 10.0), UI_Gadgets()\Text, 0.8, 0.8, 0.8, 1.0, #True, #True) : EndIf
        DrawGLBox(gx, gy, gw, gh, 0.05, 0.05, 0.05, 1.0, #True, #True)
        Define SegW.f = (gw - 6.0) / 20.0
        For i = 0 To 19
          Define segColor.f = 0.8 : If (i/20.0) > UI_Gadgets()\Value : segColor = 0.1 : EndIf
          DrawGLBox(gx + 3.0 + (i * SegW), gy + 3.0, SegW - 2.0, gh - 6.0, 0.0, segColor, segColor * 0.5, 1.0, #True, #True)
        Next

      Case #NEON_SLIDER
        If UI_Gadgets()\Text <> "" And *Fnt : DrawGLText(*Fnt, gx, gy - (TH + 6.0), UI_Gadgets()\Text, 0.6, 0.8, 1.0, 1.0, #True, #True) : EndIf
        
        DrawGLBox(gx, gy + (gh/2.0) - 5.0, gw, 10.0, 0.1, 0.1, 0.15, 1.0, #True, #True)
        DrawGLBox(gx, gy + (gh/2.0) - 5.0, gw * UI_Gadgets()\Value, 10.0, 0.0, 0.8, 1.0, 1.0, #True, #True)
        Define HandleC.f = 0.6 + (UI_Gadgets()\HoverAlpha * 0.4)
        DrawGLBox(gx + (gw * UI_Gadgets()\Value) - 8.0, gy, 16.0, gh, HandleC, HandleC, HandleC, 1.0, #True, #True)
        If UI_Gadgets()\IsFocused : DrawGLBox(gx + (gw * UI_Gadgets()\Value) - 12.0, gy - 4.0, 24.0, gh + 8.0, 0.0, 1.0, 1.0, 0.5 + (0.5 * Sin(UI_Gadgets()\FocusPulse)), #True, #True) : EndIf
    EndSelect
  Next
 
  DrawGLPolygon(UI_MouseX, UI_MouseY, 4.0, 4.0, 16, 1.0, 0.0, 0.0, 1.0, #True, #True, #True)
EndProcedure

; ============================================================================
; HYBRID INPUT SYSTEM (BUG FIXED)
; ============================================================================

Procedure Neon_UpdateInput(MousePhysX.i, MousePhysY.i, MouseClicked.b, MouseReleased.b, DPadX.i, DPadY.i, ActionPressed.b)
  MapPhysicalToVirtual(MousePhysX, MousePhysY, @UI_MouseX, @UI_MouseY)
  
  ; 1. Process Global Vertical Navigation
  If DPadY <> 0
    UI_FocusIndex + DPadY
    If UI_FocusIndex < 0 : UI_FocusIndex = ListSize(UI_Gadgets()) - 1 : EndIf
    If UI_FocusIndex >= ListSize(UI_Gadgets()) : UI_FocusIndex = 0 : EndIf
    
    SelectElement(UI_Gadgets(), UI_FocusIndex)
    While UI_Gadgets()\Type = #NEON_LABEL Or UI_Gadgets()\Type = #NEON_BREADCRUMB
      UI_FocusIndex + DPadY
      If UI_FocusIndex < 0 : UI_FocusIndex = ListSize(UI_Gadgets()) - 1 : EndIf
      If UI_FocusIndex >= ListSize(UI_Gadgets()) : UI_FocusIndex = 0 : EndIf
      SelectElement(UI_Gadgets(), UI_FocusIndex)
    Wend
  EndIf
  
  Define Index = 0
  ForEach UI_Gadgets()
    UI_Gadgets()\IsHovered = #False
    
    ; 2. Determine Mouse Hover
    If UI_Gadgets()\Type <> #NEON_LABEL And UI_Gadgets()\Type <> #NEON_BREADCRUMB
      If CheckCollisionAABB(UI_MouseX, UI_MouseY, 1.0, 1.0, UI_Gadgets()\X, UI_Gadgets()\Y, UI_Gadgets()\W, UI_Gadgets()\H)
        UI_Gadgets()\IsHovered = #True
        UI_FocusIndex = Index
      EndIf
    EndIf
    
    ; 3. Process the Focused Gadget
    If Index = UI_FocusIndex And UI_Gadgets()\Type <> #NEON_LABEL And UI_Gadgets()\Type <> #NEON_BREADCRUMB
      UI_Gadgets()\IsFocused = #True
      
;  - KEYBOARD HORIZONTAL LOGIC  -
      If DPadX <> 0
        If UI_Gadgets()\Type = #NEON_SLIDER
          UI_Gadgets()\Value + (DPadX * 0.05)
          If UI_Gadgets()\Value < 0.0 : UI_Gadgets()\Value = 0.0 : EndIf
          If UI_Gadgets()\Value > 1.0 : UI_Gadgets()\Value = 1.0 : EndIf
        ElseIf UI_Gadgets()\Type = #NEON_DIPBANK
          UI_Gadgets()\SubFocus + DPadX
          If UI_Gadgets()\SubFocus < 0 : UI_Gadgets()\SubFocus = Int(UI_Gadgets()\Value) - 1 : EndIf
          If UI_Gadgets()\SubFocus >= Int(UI_Gadgets()\Value) : UI_Gadgets()\SubFocus = 0 : EndIf
        ElseIf UI_Gadgets()\Type = #NEON_CAROUSEL
          Define TotalOptions = CountString(UI_Gadgets()\Text, "|") + 1
          UI_Gadgets()\Value + DPadX
          If UI_Gadgets()\Value < 0 : UI_Gadgets()\Value = TotalOptions - 1 : EndIf
          If UI_Gadgets()\Value >= TotalOptions : UI_Gadgets()\Value = 0 : EndIf
        EndIf
      EndIf
      
;  - MOUSE INTERACTION  -
      If UI_Gadgets()\IsHovered
        If MouseClicked
          If UI_Gadgets()\Type = #NEON_DIPBANK
            
            ; --- THE FIX: Perfectly align the mouse detection to the centered switches ---
            Define SCount.i = Int(UI_Gadgets()\Value)
            Define SwitchBlockW.f = SCount * 40.0
            Define StartX.f = UI_Gadgets()\X + (UI_Gadgets()\W / 2.0) - (SwitchBlockW / 2.0)
            
            Define LocalX.f = UI_MouseX - StartX
            If LocalX >= 0.0 And LocalX <= SwitchBlockW
              Define ClickedBit.i = Int(LocalX / 40.0)
              If ClickedBit >= 0 And ClickedBit < SCount
                UI_Gadgets()\IsActive = UI_Gadgets()\IsActive ! (1 << ClickedBit)
                UI_Gadgets()\SubFocus = ClickedBit 
              EndIf
            EndIf
            
          ElseIf UI_Gadgets()\Type = #NEON_CAROUSEL
            
            ; --- THE FIX: Add missing mouse support for Carousel arrows ---
            Define TotalOptions = CountString(UI_Gadgets()\Text, "|") + 1
            If UI_MouseX < (UI_Gadgets()\X + (UI_Gadgets()\W / 2.0))
              ; Clicked the left half of the box
              UI_Gadgets()\Value - 1 : If UI_Gadgets()\Value < 0 : UI_Gadgets()\Value = TotalOptions - 1 : EndIf
            Else
              ; Clicked the right half of the box
              UI_Gadgets()\Value + 1 : If UI_Gadgets()\Value >= TotalOptions : UI_Gadgets()\Value = 0 : EndIf
            EndIf
            
          ElseIf UI_Gadgets()\Type = #NEON_SLIDER
            UI_Gadgets()\Value = (UI_MouseX - UI_Gadgets()\X) / UI_Gadgets()\W
            If UI_Gadgets()\Value < 0.0 : UI_Gadgets()\Value = 0.0 : EndIf
            If UI_Gadgets()\Value > 1.0 : UI_Gadgets()\Value = 1.0 : EndIf
            
          ElseIf UI_Gadgets()\Type = #NEON_TOGGLE
            ; Do nothing while holding the mouse! Let the MouseReleased block handle the flip.
          Else
            UI_Gadgets()\IsActive = #True
          EndIf
        EndIf
        
        If MouseReleased
          If UI_Gadgets()\Type = #NEON_TOGGLE
            ; STRICT TOGGLE MATH
            If UI_Gadgets()\IsActive : UI_Gadgets()\IsActive = 0 : Else : UI_Gadgets()\IsActive = 1 : EndIf
          ElseIf UI_Gadgets()\Type <> #NEON_DIPBANK
            UI_Gadgets()\IsActive = #False
          EndIf
          
          ; TRIGGER CALLBACK AND SAFELY EXIT THE FRAME
          If UI_Gadgets()\Callback <> 0 
            UI_Gadgets()\Callback(UI_Gadgets()\ID, 1) 
            ProcedureReturn 
          EndIf
        EndIf
      EndIf
      
;  - KEYBOARD ACTION LOGIC  -
      If ActionPressed
        If UI_Gadgets()\Type = #NEON_DIPBANK
          ; Flip the specific bit targeted by the SubFocus cursor
          UI_Gadgets()\IsActive = UI_Gadgets()\IsActive ! (1 << UI_Gadgets()\SubFocus)
        ElseIf UI_Gadgets()\Type = #NEON_TOGGLE
          ; STRICT TOGGLE MATH
          If UI_Gadgets()\IsActive : UI_Gadgets()\IsActive = 0 : Else : UI_Gadgets()\IsActive = 1 : EndIf 
        ElseIf UI_Gadgets()\Type = #NEON_BUTTON
          UI_Gadgets()\IsActive = #False
          UI_Gadgets()\HoverAlpha = 1.5    ;FORCE THE BUTTON To VISUALLY FLASH
          
          ; TRIGGER CALLBACK AND SAFELY EXIT THE FRAME
          If UI_Gadgets()\Callback <> 0 
            UI_Gadgets()\Callback(UI_Gadgets()\ID, 1) 
            ProcedureReturn   ; PREVENTS THE "EXIT TO GAME" CRASH!
          EndIf
        EndIf
      EndIf
      
      If Not MouseClicked And UI_Gadgets()\Type <> #NEON_TOGGLE And UI_Gadgets()\Type <> #NEON_DIPBANK
        UI_Gadgets()\IsActive = #False
      EndIf

    Else
      UI_Gadgets()\IsFocused = #False
      If UI_Gadgets()\Type <> #NEON_TOGGLE And UI_Gadgets()\Type <> #NEON_DIPBANK : UI_Gadgets()\IsActive = #False : EndIf
    EndIf
    Index + 1
  Next
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 316
; FirstLine = 270
; Folding = ---
; EnableXP
; DPIAware