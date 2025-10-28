
; CoreTempMonitor
; Description .: Graphical CPU temperature monitor for Core Temp.
;              : Works only with CoreTemp: https://www.alcpu.com/CoreTemp/
; Author ......: Webarion
; Version .....: 1.0b


;- IncludeFiles

XIncludeFile "CoreTempReader.pb" ; Include our module

If Not InitializeCoreTempInfo()
  Debug "Failed to initialize library CoreTempInfo.dll"
  End
EndIf


;- Enumerations

Enumeration Window
  #Win_Sys
  #Win_Main
EndEnumeration

Enumeration Gadget
  #Gdt_Canvas
EndEnumeration

Enumeration Image
  #GraphImg
  #Icon_Image
EndEnumeration


;- Structures

Structure EX_CORE_TEMP_INFO Extends CORE_TEMP_INFO
  GraphOffset.a
  Array PrevTemp.f(0)     ; Previous temperature values
EndStructure  

Structure Config
  WinW.u
  WinH.u
  MinW.a
  Padding.a
  CntW.u
  CoreBoxH.a
  GraphH.u
  Grid.a
  FontName$
  FontSize.a
  OffsetLeft.a
EndStructure


;- Variables

Global CurrentInfo.EX_CORE_TEMP_INFO
Global Config.Config

ExamineDesktops()
Global DesktopWidth = DesktopWidth(0)

Global Mutex_Draw = CreateMutex()
Global Default_Font, Default_FontID

With Config
  \WinW = 290
  \WinH = 200
  \MinW = 250
  \CntW = \WinW - ( \Padding * 2 )
  \FontName$  = "Arial"
  \FontSize   = 14
  \Padding    = 10
  \CoreBoxH   = 10
  \GraphH     = 50
  \OffsetLeft = 10
EndWith


Global Dim CoreColor.l(0)

UsePNGImageDecoder()
Global IconImageID = CatchImage( #Icon_Image, ?Icon_Start, ?Icon_End - ?Icon_Start)


ImportC ""
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Linux
      gtk_widget_is_composited(*Widget.GtkWidget)
      gtk_window_set_opacity(*Window.GtkWindow, Opacity.D)          
  CompilerEndSelect
EndImport


Procedure WinTransparent( Window, Level.a )
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Linux
      If gtk_widget_is_composited( WindowID(Window) ) = #False
        MessageRequester("Info", "Sorry, transparency is not supported on this system!")
        End
      EndIf
    CompilerCase #PB_OS_MacOS
      Define Alpha.CGFloat
    CompilerCase #PB_OS_Windows
      SetWindowLongPtr_( WindowID(Window), #GWL_EXSTYLE, #WS_EX_LAYERED )
      SetLayeredWindowAttributes_( WindowID(Window), 0, Level, #LWA_ALPHA )
  CompilerEndSelect
EndProcedure


Procedure WinLevelTransparent( Window, Level.a )
  CompilerSelect #PB_Compiler_OS
    CompilerCase #PB_OS_Linux
      gtk_window_set_opacity( WindowID(Window), 1.0 - Level / 100.0 )
    CompilerCase #PB_OS_MacOS
      Alpha = 1.0 - Level / 100.0
      CocoaMessage( 0, WindowID(Window), "setAlphaValue:@", @Alpha )
    CompilerCase #PB_OS_Windows
      SetLayeredWindowAttributes_( WindowID(Window), 0, Int( 255 - Level / 100 * 255 ), #LWA_ALPHA )
  CompilerEndSelect
EndProcedure


Procedure UpdateConfig()
  With Config
    \CntW = \WinW - ( \Padding * 2 )
    
    If IsImage(#GraphImg)
      ResizeImage( #GraphImg, Config\CntW, Config\GraphH )
    Else
      CreateImage( #GraphImg, Config\CntW, Config\GraphH, 32, #PB_Image_Transparent )
    EndIf
    
    Default_Font = LoadFont( #PB_Any , \FontName$, \FontSize )
    If IsFont( Default_Font )
      Default_FontID = FontID( Default_Font )
    EndIf
  EndWith
EndProcedure

Procedure Init()
  GetCoreTempData(@CurrentInfo)
  UpdateConfig()
EndProcedure

;- Color manipulation functions
Procedure.l DarkenColor(Color.l, Factor.f = 0.7)
  Protected r = Red(Color) * Factor
  Protected g = Green(Color) * Factor
  Protected b = Blue(Color) * Factor
  Protected a = Alpha(Color)
  ProcedureReturn RGBA(r, g, b, a)
EndProcedure

Procedure.l LightenColor(Color.l, Factor.f = 1.3)
  Protected r = Min(Red(Color) * Factor, 255)
  Protected g = Min(Green(Color) * Factor, 255)
  Protected b = Min(Blue(Color) * Factor, 255)
  Protected a = Alpha(Color)
  ProcedureReturn RGBA(r, g, b, a)
EndProcedure

Procedure _Draw_VectorText( x.f, y.f, Text$, TextColor.l = $FF000000, ShadowColor.l = #TRANSPARENT, Width.f = 0, Flags = #PB_VectorParagraph_Left )
  Protected TH = VectorTextHeight(Text$)
  If Not Width 
    Width = VectorTextWidth(Text$)
  EndIf
  ; Text shadow
  If ShadowColor <> #TRANSPARENT
    VectorSourceColor(ShadowColor)
    MovePathCursor( x + 1, y + 1 )
    DrawVectorParagraph( Text$, Width + 1, TH, Flags )
  EndIf        
  ; Text
  If TextColor <> $FF000000
    VectorSourceColor(TextColor)
    MovePathCursor( x, y )
    DrawVectorParagraph( Text$, Width + 1, TH, Flags )
  EndIf
EndProcedure

Procedure _Draw_TempBox( x.f, y.f, w.f, h.f, Range.f, BaseColor.l )
  ; Main box background
  VectorSourceColor($FF503317)
  AddPathBox(x, y, w, h)
  FillPath()
  
  ; Box shadow
  VectorSourceLinearGradient(0, y, 0, y + 50)
  VectorSourceGradientColor($FF000000, 0.0)
  VectorSourceGradientColor($00503317, 0.08)
  AddPathBox(x, y, w, h)
  FillPath()
  
  ; Temperature bar with gradient (light top, dark bottom)
  If Range > 2
    VectorSourceLinearGradient(x, y, x, y + h)
    VectorSourceGradientColor(LightenColor(BaseColor, 1.4), 0.0)   ; Lightened top
    VectorSourceGradientColor(BaseColor, 0.3)                      ; Main color
    VectorSourceGradientColor(BaseColor, 0.7)                      ; Main color  
    VectorSourceGradientColor(DarkenColor(BaseColor, 0.6), 1.0)    ; Darkened bottom
    AddPathBox(x+1, y+1, Range-2, h-2)
    FillPath()
  ElseIf Range > 0
    ; For very narrow bars use just main color
    VectorSourceColor(BaseColor)
    AddPathBox(x+1, y+1, Range-2, h-2)
    FillPath()
  EndIf
EndProcedure


Procedure _Draw( *Info.EX_CORE_TEMP_INFO, Recourse.a = #False )
  
  If Not IsWindow(#Win_Main) : End : EndIf
  
  LockMutex( Mutex_Draw )
  
  With Config
    
    Protected core.i, cpu.i
    
    If *Info\PrevTemp(0) > 0
      If StartVectorDrawing( ImageVectorOutput(#GraphImg) )
        ; Draw line from previous point to new point
        
        For cpu = 0 To *Info\CPUCount - 1
          Protected tMax = *Info\TjMax.i(cpu)
          
          For core = 0 To *Info\CoreCount - 1
            Protected Index.i = core + ( cpu * *Info\CoreCount )
            
            ; Current temperature -> position
            Protected temperatureRatio.f = *Info\Temperatures(Index) / tMax
            If temperatureRatio > 1.0 : temperatureRatio = 1.0 : EndIf
            Protected tempPos.f = \GraphH * temperatureRatio
            
            ; Previous temperature -> position
            Protected prevTemperatureRatio.f = *Info\PrevTemp(Index) / tMax
            If prevTemperatureRatio > 1.0 : prevTemperatureRatio = 1.0 : EndIf
            Protected prevTempPos.f = \GraphH * prevTemperatureRatio
            
            AddPathBox( \CntW - 11, 0, 11, \GraphH ) ; Clip area
            ClipPath()
            
            ; Draw smooth curve from previous position to current position
            MovePathCursor( \CntW - \OffsetLeft - 1, \GraphH - prevTempPos )
            
            ; Calculate control points for smooth curve
            Protected controlX.f = (\CntW - \OffsetLeft - 1 + \CntW - 1) / 2
            Protected controlY1.f = \GraphH - prevTempPos
            Protected controlY2.f = \GraphH - tempPos
            
            ; Draw smooth Bezier curve
            AddPathCurve( controlX, controlY1, controlX, controlY2, \CntW - 1, \GraphH - tempPos )
            
            VectorSourceColor( CoreColor(Index) )
            StrokePath( 2, #PB_Path_RoundEnd )
          Next
        Next
        StopVectorDrawing()
      EndIf
    EndIf
    
    If StartVectorDrawing( CanvasVectorOutput(#Gdt_Canvas) )
      If IsFont( Default_Font ) 
        VectorFont( Default_FontID, Config\FontSize )
      EndIf
      
      Protected TextHeight = VectorTextHeight("A")
      
      If \CoreBoxH < TextHeight : \CoreBoxH = TextHeight : EndIf
      
      Protected BoxC = \CoreBoxH / 2, TextY = BoxC - ( TextHeight / 2 )
      Protected CurrentY.u = \Padding
      
      ; Main background
      VectorSourceColor($FF795126)
      FillVectorOutput()
      
      ; Background gradient
      VectorSourceLinearGradient( 0, 0, 0, \WinH )
      VectorSourceGradientColor( $00FFFFFF, 0.0 )
      VectorSourceGradientColor( $A0000000, 1.0 )
      AddPathBox( 0, 0, \WinW, \WinH )
      FillPath()
      
      ; Top highlight
      VectorSourceLinearGradient( 0, 0, 0, 2 )
      VectorSourceGradientColor( $EEFFFFFF, 0.0 )
      VectorSourceGradientColor( $00000000, 1.0 )
      AddPathBox( 0, 0, \WinW, 2 )
      FillPath()
      
      ; Bottom highlight
      VectorSourceLinearGradient( 0, \WinH, 0, 2 )
      VectorSourceGradientColor( $26000000, 0.0 )
      VectorSourceGradientColor( $00000000, 1.0 )
      AddPathBox( 0, \WinH - 2, \WinW, 2 )
      FillPath()
      
      ; Title
      _Draw_VectorText( \Padding, currentY, *Info\CPUName, $FFFFFFFF, $FF000000, \CntW )
      currentY + TextHeight + 5
      
      Protected CoreText$ = "Frequency: "
      If *Info\CPUSpeed : CoreText$ + StrF(*Info\CPUSpeed, 2) + " MHz" : Else : CoreText$ + "N/A" : EndIf : CoreText$ + " ("
      If *Info\FSBSpeed : CoreText$ + StrF(*Info\FSBSpeed, 2) : Else : CoreText$ + "N/A" : EndIf
      CoreText$ + " x " : If *Info\Multiplier : CoreText$ + StrF(*Info\Multiplier, 2) : Else : CoreText$ + "N/A" : EndIf
      CoreText$ + ")"
      
      _Draw_VectorText( \Padding, currentY, CoreText$, $FFFFFFFF, $FF000000 )
      currentY + TextHeight + 5
      
      Protected TempName$ = "°C"
      If *Info\IsFahrenheit
        TempName$ = "°F"
      EndIf
      
      Protected TextTempW = \CntW - VectorTextWidth("C99[100" + TempName$ + "] 100%")    
      
      For cpu = 0 To *Info\CPUCount - 1
        tMax = *Info\TjMax(cpu)
        
        currentY + 5
        _Draw_VectorText( \Padding, currentY, "Processor #" + Str(cpu) + ": TjMax = " + Str(tMax), $FFFFFFFF, $FF000000, \CntW )
        currentY + TextHeight + 5
        
        For core = 0 To *Info\CoreCount - 1
          Index = core + (cpu * *Info\CoreCount)
          
          Define Temperature = *Info\Temperatures(Index)
          
          ; Calculate temperature bar width
          temperatureRatio.f = Temperature / tMax
          If temperatureRatio > 1.0 : temperatureRatio = 1.0 : EndIf
          Define tempWidth.f = TextTempW * temperatureRatio
          
          Protected BoxText$ = "C" + Str(Index) + " [" + Temperature + TempName$ + "]  " + Str(*Info\Loads(index)) + "%"
          
          _Draw_VectorText( \Padding + TextTempW + 7, currentY + TextY, BoxText$, CoreColor(Index), $FF000000, TextTempW )
          _Draw_TempBox( \Padding, currentY, TextTempW, \CoreBoxH, tempWidth, CoreColor(Index) )
          
          CurrentY + \CoreBoxH + 5
        Next
      Next
      
      currentY + 5
      
      ; Graph background
      VectorSourceColor($FF503317)
      AddPathBox( \Padding, currentY, \CntW, \GraphH )
      FillPath()
      
      ; Graph shadow
      VectorSourceLinearGradient( \Padding, currentY, \Padding, currentY + \GraphH )
      VectorSourceGradientColor( $7F000000, 0.0 )
      VectorSourceGradientColor( $00503317, 0.03 )
      VectorSourceGradientColor( $00503317, 0.97 )
      VectorSourceGradientColor( $7F000000, 1.0 )
      AddPathBox( \Padding, currentY, \CntW, \GraphH )
      FillPath()
      
      VectorSourceLinearGradient( \Padding, currentY, \Padding + \CntW, currentY )
      VectorSourceGradientColor( $7F000000, 0.0 )
      VectorSourceGradientColor( $00503317, 0.01 )
      VectorSourceGradientColor( $00503317, 0.99 )
      VectorSourceGradientColor( $7F000000, 1.0 )
      AddPathBox( \Padding, currentY, \CntW, \GraphH  )
      FillPath()
      
      ; Grid lines
      Protected Grid = 10, gridY
      ; Horizontal grid lines
      For gridY = Grid To \GraphH Step 10
        MovePathCursor( \Padding, currentY + gridY + 2 )
        AddPathLine( \Padding + \CntW - 2, currentY + gridY, #PB_Path_Default )
        VectorSourceColor( $9A36210F )
        StrokePath( 0.1, #PB_Path_RoundCorner )
      Next
      
      ; Vertical grid lines
      Protected startX = ( Grid - ( *Info\GraphOffset % Grid )) % Grid
      Protected x = startX
      While x <= \CntW
        If x < \CntW ; Don't draw line on right border
          MovePathCursor( \Padding + x + 2, currentY + 2 )
          AddPathLine( \Padding + x + 2, currentY + \GraphH - 2, #PB_Path_Default )
          VectorSourceColor( $9A36210F )
          StrokePath( 0.1, #PB_Path_RoundCorner )
        EndIf
        x + Grid
      Wend
      
      ; Draw the temperature graph
      MovePathCursor( \Padding, currentY )
      DrawVectorImage( ImageID(#GraphImg), 255 )
      
      ;       If Not IsWindow(#Win_Main) : End : EndIf ; Since drawing in the stream
      
      StopVectorDrawing()
    EndIf
    
    ; Update graph image for next frame
    If StartDrawing( ImageOutput(#GraphImg) )
      DrawingMode( #PB_2DDrawing_AlphaBlend )
      GrabDrawingImage( #GraphImg, \OffsetLeft, 0, \CntW, \GraphH )
      StopDrawing()
    EndIf
    
    ; Auto-resize window if needed
    currentY + \Padding
    
    If Not Recourse And \WinH < currentY + \GraphH
      \WinH = currentY + \GraphH
      ResizeWindow( #Win_Main, #PB_Ignore, #PB_Ignore, \WinW, \WinH )
      ResizeGadget( #Gdt_Canvas, 0, 0, \WinW, \WinH )
      _Draw( *Info, #True )
    EndIf
    
    ; Save current temperatures as previous for next frame
    CopyArray( *Info\Temperatures(), *Info\PrevTemp() )
  EndWith
  
  UnlockMutex( Mutex_Draw )
EndProcedure

Procedure Demo_GenerateCurrentInfo( *Info.EX_CORE_TEMP_INFO )
  ; Fill basic information
  *Info\CPUCount = 2           ; 2 processors
  *Info\CoreCount = 4          ; 4 cores per processor
  *Info\CPUName = "Demo Intel Core i7-8700K @ 3.70GHz"
  *Info\CPUSpeed = 3700.0 + Random(500) - 200  ; 3.5 - 4.2 GHz
  *Info\FSBSpeed = 100.0 + Random(10)          ; 100-110 MHz FSB
  *Info\Multiplier = 37.0 + Random(5)          ; Multiplier
  *Info\VID = 1.2 + (Random(300) - 100) / 1000.0 ; Voltage ~1.1-1.3V
  *Info\IsFahrenheit = #False
  *Info\IsDistanceToTjMax = #False
  *Info\StructVersion = 2
  *Info\TdpSupported = #True
  *Info\PowerSupported = #True
  *Info\LastError = 0
  *Info\ErrorMessage = ""
  
  ; Calculate total cores
  Protected totalCores.i = *Info\CPUCount * *Info\CoreCount
  Protected cpu.i, core.i, Index.i
  
  ; Resize arrays according to core count
  ReDim *Info\Temperatures(totalCores - 1)
  ReDim *Info\Loads(totalCores - 1)
  ReDim *Info\TjMax(*Info\CPUCount - 1)
  ReDim *Info\Multipliers(totalCores - 1)
  ReDim *Info\Tdp(*Info\CPUCount - 1)
  ReDim *Info\Power(totalCores - 1)
  
  ; Base temperatures for each processor
  Protected Dim BaseTemps.f(10)
  BaseTemps(0) = 35.0
  BaseTemps(1) = 33.0
  
  ; TjMax for each processor
  For cpu = 0 To *Info\CPUCount - 1
    *Info\TjMax(cpu) = 100     ; Maximum temperature
    *Info\Tdp(cpu) = 95        ; TDP in watts
  Next
  
  ; Simulate processor work
  Static DemoCounter.i
  DemoCounter + 1
  
  ; Fill data for each processor and core
  For cpu = 0 To *Info\CPUCount - 1
    For core = 0 To *Info\CoreCount - 1
      Index = core + (cpu * *Info\CoreCount)
      
      ; Temperature with load simulation
      If (DemoCounter + core) % 50 < 25
        ; "Load" - increase temperature
        *Info\Temperatures(Index) = BaseTemps(cpu) + (Random(250) + 150) / 10.0  ; 15-25°C above base
      Else
        ; "Idle" - normal temperature
        *Info\Temperatures(Index) = BaseTemps(cpu) + (Random(100) + 50) / 10.0   ; 5-10°C above base
      EndIf
      
      ; Limit maximum temperature
      If *Info\Temperatures(Index) > 95.0
        *Info\Temperatures(Index) = 95.0
      EndIf
      If *Info\Temperatures(Index) < 30.0
        *Info\Temperatures(Index) = 30.0
      EndIf
      
      ; Core load depends on temperature
      *Info\Loads(Index) = (*Info\Temperatures(Index) - BaseTemps(cpu)) * 4
      If *Info\Loads(Index) > 100 
        *Info\Loads(Index) = 100 
      EndIf
      If *Info\Loads(Index) < 5 
        *Info\Loads(Index) = 5 
      EndIf
      
      ; Individual multipliers
      *Info\Multipliers(Index) = *Info\Multiplier + ( Random(20) - 10 ) / 10.0
      
      ; Power consumption
      *Info\Power(Index) = ( *Info\Loads(Index) / 100.0 ) * ( *Info\Tdp(cpu) / *Info\CoreCount ) * ( 0.8 + Random(40) / 100.0 )
    Next
  Next
EndProcedure


Procedure ThreadUpdate(*Val)
  Demo_GenerateCurrentInfo(@CurrentInfo)
;   GetCoreTempData( CurrentInfo )
  _Draw(@CurrentInfo)
EndProcedure


Procedure InitCoreColor(coreCount)
  ReDim CoreColor(coreCount - 1)
  
  Protected ColorIndex.i
  Protected BaseColor.l, i.i, j.i
  
  For i = 0 To coreCount - 1
    ColorIndex = i % 30 ; 30 colors in DataSection
    Restore CoreColor_Data
    For j = 0 To ColorIndex
      Read.l BaseColor
    Next
    CoreColor(i) = BaseColor
  Next
EndProcedure


Procedure DragWindowHandler()
  
  Static dragging.i = #False
  Static dragStartX.i, dragStartY.i
  Static windowStartX.i, windowStartY.i
  
  Select EventType()
    Case #PB_EventType_LeftButtonDown
      ; Начало перетаскивания - запоминаем позиции
      dragging = #True
      dragStartX = DesktopMouseX()
      dragStartY = DesktopMouseY()
      windowStartX = WindowX(#Win_Main)
      windowStartY = WindowY(#Win_Main)
      
    Case #PB_EventType_MouseMove
      If dragging
        ; Вычисляем смещение и перемещаем окно
        Protected currentX.i = DesktopMouseX()
        Protected currentY.i = DesktopMouseY()
        Protected deltaX.i = currentX - dragStartX
        Protected deltaY.i = currentY - dragStartY
        
        ResizeWindow(#Win_Main, windowStartX + deltaX, windowStartY + deltaY, #PB_Ignore, #PB_Ignore)
      EndIf
      
    Case #PB_EventType_LeftButtonUp
      ; Завершение перетаскивания
      dragging = #False
      
    Case #PB_EventType_RightClick
      DisplayPopupMenu(0, WindowID(#Win_Main)) 
      
  EndSelect
  
EndProcedure


Procedure _EventWin_Resize()
  ; Window resize event handler
  
  With Config
    Protected WinW.l = WindowWidth(#Win_Main)
    If WinW < \MinW
      \WinW = \MinW
    Else
      \WinW = WinW
    EndIf  
    \WinH = WindowHeight(#Win_Main)
    ResizeGadget( #Gdt_Canvas, 0, 0, \WinW, \WinH )
  EndWith
  
  UpdateConfig()
  _Draw(@CurrentInfo)
  
EndProcedure

Init()

;- GUI
If OpenWindow( #Win_Sys, -32700, -32700, 0, 0, "", #PB_Window_Invisible )
  
  If OpenWindow( #Win_Main, DesktopWidth - Config\WinW - 20, 20, Config\WinW, Config\WinH, "Core Temp Monitor", #PB_Window_Invisible | #PB_Window_BorderLess, WindowID(#Win_Sys) )
    
    WindowBounds( #Win_Main, Config\MinW, #PB_Ignore, #PB_Ignore, #PB_Ignore )
    
    WinTransparent( #Win_Main, 250 )
    StickyWindow( #Win_Main, #False )
    
    AddSysTrayIcon( 0, WindowID(#Win_Main), IconImageID )
    
        Demo_GenerateCurrentInfo( @CurrentInfo )
    
    Define CoreCount = CurrentInfo\CPUCount * CurrentInfo\CoreCount
    InitCoreColor(coreCount)
    
    CanvasGadget( #Gdt_Canvas, 0, 0, Config\WinW, Config\WinH, #PB_Canvas_Container )
    CloseGadgetList()
    
    If CreatePopupMenu(0)
      MenuItem(1, "On top of everyone")
      MenuItem(2, "Collapse")
      MenuItem(3, "Exit")
    EndIf
    
    BindEvent( #PB_Event_SizeWindow, @_EventWin_Resize(), #Win_Main ) 
    
    BindGadgetEvent( #Gdt_Canvas, @DragWindowHandler() ) 
    
    ThreadUpdate(0)
    
    AddWindowTimer( #Win_Main, 12, 1000 )
    
    Define.a HideItemState = #False, StickyState = #False
    
    HideWindow( #Win_Main, #False )
    
    Repeat
      Define Event = WaitWindowEvent()
      
      If Event = #PB_Event_Timer And EventTimer() = 12
        Define Amount = 2
        CurrentInfo\GraphOffset = ( CurrentInfo\GraphOffset + Amount ) % Config\CntW
        CreateThread( @ThreadUpdate(), 0 )
      EndIf
      
      If Event = #PB_Event_Menu
        
        Select EventMenu()
          Case 1
            StickyState = Bool( Not StickyState )
            StickyWindow( #Win_Main, StickyState )
            SetMenuItemState( 0, 1, StickyState )
          Case 2
            HideItemState = Bool( Not HideItemState )
            HideWindow( #Win_Main, HideItemState )
            If HideItemState
              SetMenuItemText(0, 2, "Show" )
            Else
              SetMenuItemText(0, 2, "Collapse" )
            EndIf
            
          Case 3
            LockMutex( Mutex_Draw )
            RemoveWindowTimer( #Win_Main, 12 )
            Break
            
        EndSelect
      EndIf
      
      If Event = #PB_Event_SysTray
        Select EventType()
          Case #PB_EventType_LeftClick
            HideWindow( #Win_Main, #False )
            StickyWindow( #Win_Main, #True )
            StickyWindow( #Win_Main, GetMenuItemState( 0, 1 ) )
            
          Case #PB_EventType_RightClick
            DisplayPopupMenu(0, WindowID(#Win_Main)) 
            
        EndSelect
      EndIf
      
    Until Event = #PB_Event_CloseWindow
    
    CloseWindow(#Win_Sys)
    FreeCoreTempInfo()
  EndIf
EndIf

DataSection
  CoreColor_Data:
  Data.l $FFa1b7f0, $FFf0a1a1, $FFa1f0b7, $FFf0f0a1, $FFf0a1e0, $FFa1e0f0, $FFb7a1f0, $FFf0b7a1
  Data.l $FF90EE90, $FFDDA0DD, $FF87CEEB, $FFFA8072, $FF40E0D0, $FFDEB887, $FF9370DB, $FF3CB371
  Data.l $FF708090, $FFFF6347, $FF6A5ACD, $FF48D1CC, $FFC71585, $FF191970, $FFF5DEB3, $FF9ACD32
  Data.l $FFFF4500, $FFDA70D6, $FFEEE8AA, $FF98FB98, $FFAFEEEE, $FFD8BFD8
  Icon_Start:
  IncludeBinary "icon.png"
  Icon_End:
EndDataSection



; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 3
; Folding = ----
; EnableThread
; EnableXP
; DPIAware
; UseIcon = icon.ico
; Executable = CoreTempViewer.exe
; EnablePurifier