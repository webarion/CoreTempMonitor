

;- IncludeFiles

XIncludeFile "CoreTempReader.pb" ; Подключаем наш модуль

If Not InitializeCoreTempInfo()
  Debug "Failed to initialize library CoreTempInfo.dll"
  End
EndIf

XIncludeFile "TransparentWindow_Crossplatform.pb"


;- Enumerations

Enumeration Window
  #Win_Sys
  #Win_Main
EndEnumeration

Enumeration Gadget
  #Gdt_Canvas
EndEnumeration

Enumeration Images
  #Icon_Image
EndEnumeration

;- Structures

Structure Graph1
  TitleH.a
  Title_PaddingB.a
  BoxW.u
  BoxH.u
  Box_PaddingB.a
EndStructure

Structure Graph2
  TitleH.a
  Title_PaddingB.a
  BoxW.u
  BoxH.u
  Box_PaddingB.a
EndStructure

Structure Config
  
  FontName.s
  FontSize.a
  
  GdtW.u
  GdtH.u
  
  Gdt_PaddingL.a
  Gdt_PaddingR.a
  Gdt_PaddingT.a
  Gdt_PaddingB.a
  
  Graph1.Graph1
  Graph2.Graph2
  
  Show_Title.a
  Show_Temperature.a
  Show_Loads.a
  
  
  
EndStructure


;- Variables

Global CurrentInfo.CORE_TEMP_INFO


Global Config.Config


ExamineDesktops()

Global DesktopWidth = DesktopWidth(0)

UsePNGImageDecoder()
Global IconImageID = CatchImage( #Icon_Image, ?Icon_Start, ?Icon_End - ?Icon_Start)

With Config
  
  \FontName = "Arial"
  \FontSize = 12
  
  \GdtW = 300
  \GdtH = 300
  
  \Gdt_PaddingL = 10
  \Gdt_PaddingR = 10
  \Gdt_PaddingT = 10
  \Gdt_PaddingB = 10
  
  \Graph1\TitleH = 25
  \Graph1\Title_PaddingB = 5
  \Graph1\BoxH = 30
  \Graph1\Box_PaddingB = 5
  
  \Graph2\TitleH = 25
  \Graph2\Title_PaddingB = 5
  \Graph2\BoxH = 25
  
  \Show_Temperature = #True
  \Show_Loads = #True
  
EndWith


Global Mutex_Draw = CreateMutex()
Global Default_Font, Default_FontID



Procedure Init()
  GetCoreTempData(@CurrentInfo)
  
  With Config
    
    \Graph1\BoxW = \GdtW - \Gdt_PaddingL - \Gdt_PaddingR
    
    \GdtH = ( CurrentInfo\CPUCount * ( \Graph1\TitleH + \Graph1\Title_PaddingB ) ) + ( CurrentInfo\CoreCount * ( \Graph1\BoxH + \Graph1\Box_PaddingB ) ) - \Gdt_PaddingB - \Graph1\Box_PaddingB
    
    Default_Font = LoadFont( #PB_Any , \FontName , \FontSize )
    If IsFont( Default_Font )
      Default_FontID = FontID( Default_Font )
    EndIf
    
  EndWith
  
EndProcedure




; Процедура для получения цвета температуры из спектра
; t - текущая температура (0..tMax)
; tMax - максимальная температура
; Возвращает цвет в формате RGB
Procedure.i GetTemperatureColor(t.f, tMax.f)
  Protected ratio.f
  
  ; Вычисляем соотношение температуры (0.0 - 1.0)
  If tMax > 0
    ratio = t / tMax
  Else
    ratio = 0
  EndIf
  
  ; Ограничиваем диапазон
  If ratio < 0 : ratio = 0 : EndIf
  If ratio > 1 : ratio = 1 : EndIf
  
  ; Цветовой спектр от синего к красному через зеленый
  Protected red.i, green.i, blue.i
  
  If ratio < 0.5
    ; Синий -> Зеленый (0.0 - 0.5)
    ratio = ratio * 2.0 ; Нормализуем к 0.0-1.0
    red = 0
    green = Int(255 * ratio)
    blue = Int(255 * (1.0 - ratio))
  Else
    ; Зеленый -> Красный (0.5 - 1.0)
    ratio = (ratio - 0.5) * 2.0 ; Нормализуем к 0.0-1.0
    red = Int(255 * ratio)
    green = Int(255 * (1.0 - ratio))
    blue = 0
  EndIf
  
  ProcedureReturn RGB(red, green, blue)
EndProcedure

; Альтернативная версия с плавным градиентом через весь спектр
Procedure.i GetTemperatureColorSmooth(t.f, tMax.f)
  Protected ratio.f
  
  ; Вычисляем соотношение температуры (0.0 - 1.0)
  If tMax > 0
    ratio = t / tMax
  Else
    ratio = 0
  EndIf
  
  ; Ограничиваем диапазон
  If ratio < 0 : ratio = 0 : EndIf
  If ratio > 1 : ratio = 1 : EndIf
  
  ; Плавный переход через синий-голубой-зеленый-желтый-красный
  Protected red.i, green.i, blue.i
  
  If ratio < 0.25
    ; Синий -> Голубой
    ratio = ratio * 4.0
    red = 0
    green = Int(255 * ratio)
    blue = 255
  ElseIf ratio < 0.5
    ; Голубой -> Зеленый
    ratio = (ratio - 0.25) * 4.0
    red = 0
    green = 255
    blue = Int(255 * (1.0 - ratio))
  ElseIf ratio < 0.75
    ; Зеленый -> Желтый
    ratio = (ratio - 0.5) * 4.0
    red = Int(255 * ratio)
    green = 255
    blue = 0
  Else
    ; Желтый -> Красный
    ratio = (ratio - 0.75) * 4.0
    red = 255
    green = Int(255 * (1.0 - ratio))
    blue = 0
  EndIf
  
  ProcedureReturn RGB(red, green, blue)
EndProcedure







; Версия для векторного рисования (возвращает ARGB)
Procedure.i GetTemperatureColorARGB(t.f, tMax.f, alpha.i = 255)
  Protected color.i = GetTemperatureColor(t, tMax)
  Protected red.i = Red(color)
  Protected green.i = Green(color)
  Protected blue.i = Blue(color)
  
  ProcedureReturn RGBA(red, green, blue, alpha)
EndProcedure







; Пример использования в вашей процедуре Draw:
Procedure Graph1_Draw( *Info.CORE_TEMP_INFO )
  
  LockMutex( Mutex_Draw )
  
  
  
  
  With Config
    
    ;   \Show_Temperature = 0
    ;   \Show_Loads = 1
    ;     
    
    If StartVectorDrawing(CanvasVectorOutput(#Gdt_Canvas))
      ;       Protected OW = VectorOutputWidth(), OH = VectorOutputHeight()
      
      VectorFont( Default_FontID, \FontSize )
      
      ; Заливаем фон
      VectorSourceColor($FF600000)
      FillVectorOutput()
      
      Define cpu.i, core.i
      Define currentY.i = \Gdt_PaddingT
      
      
      If Not \Show_Temperature And Not \Show_Loads
        \Show_Temperature = #True
        SetMenuItemState(0, 1, #True )
      EndIf
      
      Protected CountStrip.a = \Show_Temperature + \Show_Loads
      Protected StripH.a = \Graph1\BoxH / CountStrip     
      
      Protected textHeight.i = VectorTextHeight("A")
      
      For cpu = 0 To *Info\CPUCount - 1
        Protected tMax.f = *Info\TjMax(cpu)
        
        ; Заголовок
        If \Show_Title
          VectorSourceColor($FF000000)
          
          Protected textY.i = currentY + ( \Graph1\TitleH - textHeight ) / 2
          
          MovePathCursor( \Gdt_PaddingL + 5, textY )
          DrawVectorParagraph("Процессор " + Str(cpu) + ": " + *Info\CPUName, \Graph1\BoxW - 10, \Graph1\BoxH, #PB_VectorParagraph_Center)
          
          currentY + \Graph1\TitleH + \Graph1\Title_PaddingB
          
        EndIf
        
        
        
        
        
        
        
        
        
        ; Ядра процессора
        For core = 0 To *Info\CoreCount - 1
          Define Index = core + (cpu * *Info\CoreCount)
          
          
          ; Фон температурной шкалы (серая)
          VectorSourceColor($FF888888)
          AddPathBox( \Gdt_PaddingL, currentY, \Graph1\BoxW, \Graph1\BoxH )
          FillPath()
          
          
          Protected CoreNum$ = "Ядро " + Str(index)
          
          VectorSourceColor($FF000000)
          MovePathCursor( \Gdt_PaddingL, currentY )
          DrawVectorParagraph( CoreNum$, \Graph1\BoxW - 2, \Graph1\BoxH, #PB_VectorParagraph_Right )
          
          
          If CountStrip = 2
            VectorSourceColor($FF444444)
            AddPathBox( \Gdt_PaddingL, ( currentY + ( CountStrip - 1 ) * StripH ) - 1, \Graph1\BoxW, 2 )
            FillPath()
          EndIf
          
          
          If \Show_Temperature
            
            Define Temperature = *Info\Temperatures(index)
            Protected tempColor.i = GetTemperatureColorARGB(Temperature, tMax, 255)
            
            ; Расчет ширины температурной полосы
            Protected temperatureRatio.f = Temperature / tMax
            If temperatureRatio > 1.0 : temperatureRatio = 1.0 : EndIf
            Define tempWidth.f = \Graph1\BoxW * temperatureRatio
            
            
            
            ; Температурная полоса
            VectorSourceColor(tempColor)
            AddPathBox( \Gdt_PaddingL, currentY, tempWidth, StripH )
            FillPath()
            
            
            
            ; Текст с информацией о ядре через DrawVectorParagraph
            VectorSourceColor($FF000000)
            
            textY = currentY
            
            If CountStrip = 1
              textY + ( \Graph1\BoxH - textHeight ) / 2
            EndIf
            
            MovePathCursor( \Gdt_PaddingL + 5, textY )
            DrawVectorParagraph( "Темпаратура: " + Str(Temperature) + " °C", \Graph1\BoxW - 10, \Graph1\BoxH, #PB_VectorParagraph_Left )
            
          EndIf
          
          
          If \Show_Loads
            
            Protected LoadsY.a = ( CountStrip - 1 ) * StripH
            
            Define Loads.f = *Info\Loads(index)
            Protected LoadsColor.i = GetTemperatureColorARGB(Loads, 100, 255)
            
            ; Расчет ширины полосы загрузки
            Protected LoadsRatio.f = Loads / 100
            If temperatureRatio > 1.0 : LoadsRatio = 1.0 : EndIf
            Define LoadsWidth.f = \Graph1\BoxW * LoadsRatio
            
            
            
            ; Полоса загрузки
            VectorSourceColor(LoadsColor)
            AddPathBox( \Gdt_PaddingL, currentY + LoadsY, LoadsWidth, StripH )
            FillPath()
            
            
            
            ; Текст
            VectorSourceColor($FF000000)
            
            textY = currentY
            
            If CountStrip = 1
              textY + ( \Graph1\BoxH - textHeight ) / 2
            Else
              textY + LoadsY
            EndIf
            
            MovePathCursor( \Gdt_PaddingL + 5, textY )
            DrawVectorParagraph( "Загрузка: " + Str(*Info\Loads(index)) + "%", \Graph1\BoxW - 10, \Graph1\BoxH, #PB_VectorParagraph_Left )
            
          EndIf
          
          
          ; Рамка
          VectorSourceColor($FF000000)
          AddPathBox( \Gdt_PaddingL, currentY, \Graph1\BoxW, \Graph1\BoxH )
          StrokePath(1)
          
          
          currentY + \Graph1\BoxH + \Graph1\Box_PaddingB
        Next
        
        ; Добавляем отступ между процессорами
        currentY + 10
      Next
      
      StopVectorDrawing()
    EndIf
    
  EndWith
  
  UnlockMutex( Mutex_Draw )
  
EndProcedure







; Процедура для отладки - показывает цвета для разных температур
Procedure DebugTemperatureColors(tMax.f = 100.0)
  Debug "Цвета температур от 0 до " + StrF(tMax, 1) + ":"
  
  Protected i.i
  For i = 0 To 10
    Protected t.f = i * (tMax / 10.0)
    Protected color.i = GetTemperatureColor(t, tMax)
    Debug "Температура " + StrF(t, 1) + ": RGB(" + 
          Str(Red(color)) + ", " + Str(Green(color)) + ", " + Str(Blue(color)) + ")"
  Next
EndProcedure

; Вызов для тестирования:
; DebugTemperatureColors(100.0)



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



Procedure _Event_Size()
  Config\GdtW = WindowWidth(#Win_Main)
  Config\GdtH = WindowHeight(#Win_Main)
  Init()
  ResizeGadget( #Win_Main, #PB_Ignore, #PB_Ignore, Config\GdtW, Config\GdtH )
  GetCoreTempData(@CurrentInfo)
  Graph1_Draw(@CurrentInfo)
EndProcedure



Procedure ThreadUpdate(*Val)
  GetCoreTempData(@CurrentInfo)
  Graph1_Draw(@CurrentInfo)
EndProcedure


;- GUI



Init()

If OpenWindow( #Win_Sys, -32700, -32700, 0, 0, "", #PB_Window_Invisible ) ; чтобы скрыть значёк на панели задач
  
  If OpenWindow( #Win_Main, DesktopWidth - Config\GdtW - 20, 20, Config\GdtW, Config\GdtH, "Пример Канвас контейнер", #PB_Window_BorderLess, WindowID(#Win_Sys) )
    
    WinTransparent( #Win_Main, 220 )
    
    SmartWindowRefresh( #Win_Main, #True )
    StickyWindow( #Win_Main, #True ) 
    
    AddSysTrayIcon( 0, WindowID(#Win_Main), IconImageID )
    
    
    CanvasGadget( #Gdt_Canvas, 0, 0, Config\GdtW, Config\GdtH )
    
    If CreatePopupMenu(0)
      MenuItem(1, "Температура ядра")
      MenuItem(2, "Загрузка ядра")
      
      MenuItem(8, "Свернуть")
      MenuItem(9, "Закрыть")
      
      SetMenuItemState(0, 1, Config\Show_Temperature)
      SetMenuItemState(0, 2, Config\Show_Loads)
      
    EndIf
    
    BindEvent( #PB_Event_SizeWindow, @_Event_Size(), #Win_Main ) 
    
    AddWindowTimer( #Win_Main, 12, 1000 )
    
    GetCoreTempData(@CurrentInfo)
    Graph1_Draw(@CurrentInfo)
    
    BindGadgetEvent( #Gdt_Canvas, @DragWindowHandler() ) 
    
    Define HideItemState.a = #False
    
    Repeat
      Define Event = WaitWindowEvent()
      
      If Event = #PB_Event_Timer And EventTimer() = 12
        CreateThread( @ThreadUpdate(), 0 )
      EndIf
      
      Define StateMenu.a
      
      If Event = #PB_Event_Menu
        Select EventMenu()
          Case 1
            StateMenu = Bool( Not GetMenuItemState(0, 1) )
            Config\Show_Temperature = StateMenu
            SetMenuItemState(0, 1, StateMenu )
            Graph1_Draw(@CurrentInfo)
          Case 2
            StateMenu = Bool( Not GetMenuItemState(0, 2) )
            Config\Show_Loads = StateMenu
            SetMenuItemState(0, 2, StateMenu )
            Graph1_Draw(@CurrentInfo)
            
          Case 8
            HideItemState = Bool( Not HideItemState )
            HideWindow( #Win_Main, HideItemState )
            If HideItemState
              SetMenuItemText(0, 8, "Показать" )
            Else
              SetMenuItemText(0, 8, "Свернуть" )
            EndIf
            
          Case 9
            Break
            
        EndSelect
      EndIf
      
      If Event = #PB_Event_SysTray
        Select EventType()
          Case #PB_EventType_LeftClick
            HideWindow( #Win_Main, #False )
            
          Case #PB_EventType_RightClick
            DisplayPopupMenu(0, WindowID(#Win_Main)) 
            
        EndSelect
      EndIf
      
    Until Event = #PB_Event_CloseWindow
    
    RemoveSysTrayIcon(0)
    FreeMenu(0)
    CloseWindow(#Win_Sys)
    FreeCoreTempInfo()
    
  EndIf
  
EndIf




;- DataSection
DataSection
  Icon_Start:
  IncludeBinary "thermometer.png"
  Icon_End:
EndDataSection



; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 591
; FirstLine = 323
; Folding = -T--
; EnableThread
; EnableXP
; DPIAware
; UseIcon = icon.ico
; Executable = CoreTempViewer.exe
; EnablePurifier