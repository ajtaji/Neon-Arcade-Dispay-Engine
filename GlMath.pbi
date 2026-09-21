; ============================================================================
; GlMath.pbi - High Performance Collision & Math
; ============================================================================

; 1. AABB (Axis-Aligned Bounding Box) 
; PERFECT FOR: UI Elements, Mouse Clicks, and Non-Rotating Walls
Procedure.b CheckCollisionAABB(x1.f, y1.f, w1.f, h1.f, x2.f, y2.f, w2.f, h2.f)
  If x1 < x2 + w2 And x1 + w1 > x2 And y1 < y2 + h2 And y1 + h1 > y2
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

; 2. Radial Collision (Distance Squared)
; PERFECT FOR: Rotating Ships, Bullets, Particles, and Characters
Procedure.b CheckCollisionCircle(x1.f, y1.f, Radius1.f, x2.f, y2.f, Radius2.f)
  Define dx.f = x1 - x2
  Define dy.f = y1 - y2
  
  ; PRO TRICK: Square the distance instead of using the heavy Sqr() function
  Define DistanceSquared.f = (dx * dx) + (dy * dy)
  Define RadiiSquared.f = (Radius1 + Radius2) * (Radius1 + Radius2)
  
  If DistanceSquared <= RadiiSquared
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure
; 3. Pixel-Perfect Alpha Mask Collision (Supports Rotation & Scale)
Procedure.b CheckCollisionPixelPerfect(*S1.GLSprite, X1.f, Y1.f, Angle1.f, Scale1.f, *S2.GLSprite, X2.f, Y2.f, Angle2.f, Scale2.f)
  If Not *S1 Or Not *S2 : ProcedureReturn #False : EndIf
  
  ; Calculate physical sizes
  Define W1.f = *S1\Width * Scale1, H1.f = *S1\Height * Scale1
  Define W2.f = *S2\Width * Scale2, H2.f = *S2\Height * Scale2
  
  ; Define centers for rotation math
  Define CX1.f = X1 + (W1 / 2.0), CY1.f = Y1 + (H1 / 2.0)
  Define CX2.f = X2 + (W2 / 2.0), CY2.f = Y2 + (H2 / 2.0)
  
  ; ---> BROAD-PHASE (Radial Check) <---
  ; Use the longest dimension as a worst-case scenario bounding circle
  Define MaxRadius1.f = W1 : If H1 > W1 : MaxRadius1 = H1 : EndIf
  Define MaxRadius2.f = W2 : If H2 > W2 : MaxRadius2 = H2 : EndIf
  If Not CheckCollisionCircle(CX1, CY1, MaxRadius1/2.0, CX2, CY2, MaxRadius2/2.0)
    ProcedureReturn #False ; They are nowhere near each other, abort to save CPU!
  EndIf
  
  ; ---> NARROW-PHASE (Pixel Inverse Matrix) <---
  ; Pre-calculate sine and cosine for the INVERSE rotations (-Angle)
  Define Cos1.f = Cos(-Angle1), Sin1.f = Sin(-Angle1)
  Define Cos2.f = Cos(-Angle2), Sin2.f = Sin(-Angle2)
  
  ; Define a scan area bounding box based on Sprite 1's position
  Define ScanLeft.i = X1 - MaxRadius1, ScanRight.i = X1 + MaxRadius1
  Define ScanTop.i = Y1 - MaxRadius1, ScanBottom.i = Y1 + MaxRadius1
  
  Define px, py
  Define LocalX1.i, LocalY1.i, LocalX2.i, LocalY2.i
  Define OffsetX.f, OffsetY.f
  
  ; Scan the screen pixels where the two sprites might overlap
  For py = ScanTop To ScanBottom
    For px = ScanLeft To ScanRight
      
      ; Map screen pixel to Sprite 1's local memory layout
      OffsetX = px - CX1
      OffsetY = py - CY1
      LocalX1 = ((OffsetX * Cos1 - OffsetY * Sin1) / Scale1) + (*S1\Width / 2.0)
      LocalY1 = ((OffsetX * Sin1 + OffsetY * Cos1) / Scale1) + (*S1\Height / 2.0)
      
      ; If the pixel lands inside Sprite 1's physical image boundaries...
      If LocalX1 >= 0 And LocalX1 < *S1\Width And LocalY1 >= 0 And LocalY1 < *S1\Height
        ; ...and the pixel is solid (1)
        If PeekB(*S1\AlphaMask + (LocalY1 * *S1\Width) + LocalX1) = 1
          
          ; Map the EXACT SAME screen pixel to Sprite 2's local memory layout
          OffsetX = px - CX2
          OffsetY = py - CY2
          LocalX2 = ((OffsetX * Cos2 - OffsetY * Sin2) / Scale2) + (*S2\Width / 2.0)
          LocalY2 = ((OffsetX * Sin2 + OffsetY * Cos2) / Scale2) + (*S2\Height / 2.0)
          
          ; If it lands inside Sprite 2...
          If LocalX2 >= 0 And LocalX2 < *S2\Width And LocalY2 >= 0 And LocalY2 < *S2\Height
            ; ...and Sprite 2's pixel is ALSO solid, we have a true pixel-perfect collision!
            If PeekB(*S2\AlphaMask + (LocalY2 * *S2\Width) + LocalX2) = 1
              ProcedureReturn #True
            EndIf
          EndIf
          
        EndIf
      EndIf
      
    Next
  Next
  
  ProcedureReturn #False
EndProcedure
; ============================================================================
; GlMath.pbi - Convex Hull & Polygon Generation
; ============================================================================


; Helper: Cross Product tells us if three points make a Left turn or Right turn
Procedure.f Math_CrossProduct(O_x.f, O_y.f, A_x.f, A_y.f, B_x.f, B_y.f)
  ProcedureReturn (A_x - O_x) * (B_y - O_y) - (A_y - O_y) * (B_x - O_x)
EndProcedure

; The Jarvis March (Gift Wrapping) Algorithm
Procedure.i GenerateSpriteHull(*Sprite.GLSprite)
  If Not *Sprite Or Not *Sprite\AlphaMask : ProcedureReturn 0 : EndIf
  
  NewList P.GLPoint()
  Define x, y
  
  ; 1. Collect all solid pixels and shift them so (0,0) is the center of the sprite
  ; (This perfectly aligns the polygon with your center-of-mass rotation logic!)
  Define HalfW.f = *Sprite\Width / 2.0
  Define HalfH.f = *Sprite\Height / 2.0
  
  For y = 0 To *Sprite\Height - 1
    For x = 0 To *Sprite\Width - 1
      If PeekB(*Sprite\AlphaMask + (y * *Sprite\Width) + x) = 1
        AddElement(P())
        P()\x = x - HalfW
        P()\y = y - HalfH
      EndIf
    Next
  Next
  
  If ListSize(P()) < 3 : ProcedureReturn 0 : EndIf ; Cannot make a polygon with < 3 pixels
  
  ; 2. Find the leftmost pixel to start the wrapping process
  Define LeftMost = 0, i = 0
  SelectElement(P(), 0)
  Define MinX.f = P()\x
  
  ForEach P()
    If P()\x < MinX
      MinX = P()\x
      LeftMost = ListIndex(P())
    EndIf
  Next
  
  ; 3. The Gift Wrapping Loop
  NewList Hull.GLPoint()
  Define CurrentPoint = LeftMost
  Define NextPoint
  
  Repeat
    ; Add the current point to our hull
    SelectElement(P(), CurrentPoint)
    AddElement(Hull())
    Hull()\x = P()\x : Hull()\y = P()\y
    
    ; Pick the next point arbitrarily
    NextPoint = (CurrentPoint + 1) % ListSize(P())
    
    ; Check all other points. If another point is further counter-clockwise, it becomes the new NextPoint
    For i = 0 To ListSize(P()) - 1
      SelectElement(P(), CurrentPoint)
      Define Cx.f = P()\x, Cy.f = P()\y
      
      SelectElement(P(), i)
      Define Ix.f = P()\x, Iy.f = P()\y
      
      SelectElement(P(), NextPoint)
      Define Nx.f = P()\x, Ny.f = P()\y
      
      If Math_CrossProduct(Cx, Cy, Ix, Iy, Nx, Ny) < 0.0
        NextPoint = i
      EndIf
    Next
    
    CurrentPoint = NextPoint
  Until CurrentPoint = LeftMost ; We wrapped all the way around!
  
  ; 4. Pack the linked list into a high-speed contiguous memory block
  Define *Poly.GLPolygon = AllocateMemory(SizeOf(GLPolygon))
  *Poly\VertexCount = ListSize(Hull())
  *Poly\Vertices = AllocateMemory(*Poly\VertexCount * SizeOf(GLPoint))
  
  Define *Ptr.GLPoint = *Poly\Vertices
  ForEach Hull()
    *Ptr\x = Hull()\x
    *Ptr\y = Hull()\y
    *Ptr + SizeOf(GLPoint)
  Next
  
  FreeList(P())
  FreeList(Hull())
  
  ProcedureReturn *Poly
EndProcedure

; ============================================================================
; 4. SAT (Separating Axis Theorem) Polygon Collision
; ============================================================================

; Internal helper to project a polygon onto a mathematical axis
Procedure ProjectPolygon(*Poly.GLPolygon, OffsetX.f, OffsetY.f, AxisX.f, AxisY.f, *MinOut.Float, *MaxOut.Float)
  Define *Ptr.GLPoint = *Poly\Vertices
  Define MinProj.f = (*Ptr\x + OffsetX) * AxisX + (*Ptr\y + OffsetY) * AxisY
  Define MaxProj.f = MinProj
  
  Define i
  *Ptr + SizeOf(GLPoint)
  For i = 1 To *Poly\VertexCount - 1
    Define Proj.f = (*Ptr\x + OffsetX) * AxisX + (*Ptr\y + OffsetY) * AxisY
    If Proj < MinProj : MinProj = Proj : EndIf
    If Proj > MaxProj : MaxProj = Proj : EndIf
    *Ptr + SizeOf(GLPoint)
  Next
  
  *MinOut\f = MinProj
  *MaxOut\f = MaxProj
EndProcedure

; The main SAT Collision Check
Procedure.b CheckCollisionSAT(*PolyA.GLPolygon, OffsetAX.f, OffsetAY.f, *PolyB.GLPolygon, OffsetBX.f, OffsetBY.f)
  If Not *PolyA Or Not *PolyB : ProcedureReturn #False : EndIf
  
  Define i, j
  Define *Polys.GLPolygon, *OtherPoly.GLPolygon
  Define OffsetX.f, OffsetY.f, OtherOffsetX.f, OtherOffsetY.f
  
  ; We must check the normal axes of BOTH polygons
  For j = 0 To 1
    If j = 0
      *Polys = *PolyA : OffsetX = OffsetAX
      *OtherPoly = *PolyB : OtherOffsetX = OffsetBX
    Else
      *Polys = *PolyB : OffsetX = OffsetBX
      *OtherPoly = *PolyA : OtherOffsetY = OffsetAX
    EndIf
    
    Define *Ptr1.GLPoint, *Ptr2.GLPoint
    For i = 0 To *Polys\VertexCount - 1
      *Ptr1 = *Polys\Vertices + (i * SizeOf(GLPoint))
      
      If i + 1 = *Polys\VertexCount
        *Ptr2 = *Polys\Vertices ; Wrap back to the first point
      Else
        *Ptr2 = *Polys\Vertices + ((i + 1) * SizeOf(GLPoint))
      EndIf
      
      ; Get the edge vector
      Define EdgeX.f = *Ptr2\x - *Ptr1\x
      Define EdgeY.f = *Ptr2\y - *Ptr1\y
      
      ; Calculate the perpendicular Normal Axis
      Define AxisX.f = -EdgeY
      Define AxisY.f = EdgeX
      
      ; Normalize the axis
      Define Len.f = Sqr(AxisX * AxisX + AxisY * AxisY)
      If Len = 0.0 : Continue : EndIf
      AxisX / Len : AxisY / Len
      
      ; Project both polygons onto this axis
      Define MinA.f, MaxA.f, MinB.f, MaxB.f
      ProjectPolygon(*PolyA, OffsetAX, OffsetAY, AxisX, AxisY, @MinA, @MaxA)
      ProjectPolygon(*PolyB, OffsetBX, OffsetBY, AxisX, AxisY, @MinB, @MaxB)
      
      ; If there is a gap on THIS axis, they are mathematically NOT colliding!
      If MaxA < MinB Or MaxB < MinA
        ProcedureReturn #False
      EndIf
    Next
  Next
  
  ; If we checked every single axis and found no gaps, they MUST be colliding
  ProcedureReturn #True
EndProcedure

; ============================================================================
; 5. SPLINES & RAYCASTING
; ============================================================================

; Calculates a point on a Cubic Bezier curve (0.0 <= t <= 1.0)
Procedure Math_CalculateBezierCubic(t.f, p0x.f, p0y.f, p1x.f, p1y.f, p2x.f, p2y.f, p3x.f, p3y.f, *OutX.Float, *OutY.Float)
  Define u.f = 1.0 - t
  Define tt.f = t * t
  Define uu.f = u * u
  Define uuu.f = uu * u
  Define ttt.f = tt * t

  *OutX\f = uuu * p0x + 3 * uu * t * p1x + 3 * u * tt * p2x + ttt * p3x
  *OutY\f = uuu * p0y + 3 * uu * t * p1y + 3 * u * tt * p2y + ttt * p3y
EndProcedure

; Fast Line Segment Intersection (Hit-scan Raycasting)
Procedure.b CheckCollisionLineLine(x1.f, y1.f, x2.f, y2.f, x3.f, y3.f, x4.f, y4.f, *OutX.Float = 0, *OutY.Float = 0)
  Define den.f = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
  If den = 0.0 : ProcedureReturn #False : EndIf ; Lines are parallel

  Define t.f = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
  Define u.f = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den

  ; If both t and u are between 0 and 1, the segments physically cross
  If t > 0.0 And t < 1.0 And u > 0.0 And u < 1.0
    If *OutX : *OutX\f = x1 + t * (x2 - x1) : EndIf
    If *OutY : *OutY\f = y1 + t * (y2 - y1) : EndIf
    ProcedureReturn #True
  EndIf
  
  ProcedureReturn #False
EndProcedure

; Raycast against a Bounding Circle
Procedure.b CheckCollisionLineCircle(x1.f, y1.f, x2.f, y2.f, cx.f, cy.f, r.f)
  Define dx.f = x2 - x1, dy.f = y2 - y1
  Define len2.f = dx * dx + dy * dy
  
  ; Fallback if the line is actually just a single point
  If len2 = 0.0 : ProcedureReturn CheckCollisionCircle(x1, y1, 0, cx, cy, r) : EndIf
  
  ; Find the mathematical closest point on the infinite line
  Define t.f = ((cx - x1) * dx + (cy - y1) * dy) / len2
  
  ; Clamp that point to our actual line segment
  If t < 0.0 : t = 0.0 : ElseIf t > 1.0 : t = 1.0 : EndIf
  
  Define nearX.f = x1 + t * dx, nearY.f = y1 + t * dy
  
  ; Check if the closest point on the segment is inside the circle
  ProcedureReturn CheckCollisionCircle(nearX, nearY, 0, cx, cy, r)
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 102
; FirstLine = 81
; Folding = --
; EnableXP
; DPIAware