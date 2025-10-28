
; Library for reading Core Temp data
; The author ...: Webarion
; Version ..: 1.0
; License .: Free

EnableExplicit

;- Constants

#UNKNOWN_EXCEPTION = $20000000

; Prototypes
Prototype.i ProtoGetCoreTempInfoAlt(*pData)


;- Structures

Structure CORE_TEMP_SHARED_DATA_EX Align 4
  ; Original structure (CoreTempSharedData)
  uiLoad.l[256]           ; Загрузка каждого ядра в процентах (0-100%), индексация: ядро + (процессор * CoreCount)
  uiTjMax.l[128]          ; Максимальная температура для каждого процессора (Tjunction Max) в градусах
  uiCoreCnt.l             ; Количество ядер на одном процессоре
  uiCPUCnt.l              ; Количество физических процессоров в системе
  fTemp.f[256]            ; Температура каждого ядра, индексация: ядро + (процессор * CoreCount)
  fVID.f                  ; Напряжение VID (Voltage ID) процессора в вольтах
  fCPUSpeed.f             ; Текущая частота процессора в МГц
  fFSBSpeed.f             ; Частота системной шины (FSB) в МГц
  fMultiplier.f           ; Общий множитель процессора
  sCPUName.a[100]         ; Название процессора (ASCII строка)
  ucFahrenheit.a          ; Флаг единиц измерения температуры: 0=Цельсий, 1=Фаренгейт
  ucDeltaToTjMax.a        ; Флаг типа температуры: 0=фактическая температура, 1=расстояние до TjMax
  ; Расширенные поля (uiStructVersion = 2)
  ucTdpSupported.a        ; Флаг поддержки TDP: 0=не поддерживается, 1=поддерживается
  ucPowerSupported.a      ; Флаг поддержки мощности: 0=не поддерживается, 1=поддерживается
  uiStructVersion.l       ; Версия структуры данных (2 для этой версии)
  uiTdp.l[128]            ; TDP (Thermal Design Power) каждого процессора в ваттах
  fPower.f[128]           ; Потребляемая мощность каждого ядра в ваттах, индексация: ядро + (процессор * CoreCount)
  fMultipliers.f[256]     ; Индивидуальные множители для каждого ядра, индексация: ядро + (процессор * CoreCount)
EndStructure

; Структура для удобного доступа к данным
Structure CORE_TEMP_INFO
  ; Основная информация
  CPUName.s               ; Название процессора
  CPUSpeed.f              ; Текущая частота процессора в МГц
  FSBSpeed.f              ; Частота системной шины в МГц
  Multiplier.f            ; Общий множитель процессора
  VID.f                   ; Напряжение VID процессора в вольтах
  CPUCount.i              ; Количество физических процессоров
  CoreCount.i             ; Количество ядер на процессоре
  IsFahrenheit.i          ; Флаг единиц температуры: 0=Цельсий, 1=Фаренгейт
  IsDistanceToTjMax.i     ; Флаг типа температуры: 0=фактическая, 1=расстояние до TjMax
  ; Массивы данных
  Array Temperatures.f(0) ; Массив температур всех ядер системы
  Array Loads.i(0)        ; Массив загрузки всех ядер системы в процентах
  Array TjMax.i(0)        ; Массив TjMax значений для каждого процессора
  Array Multipliers.f(0)  ; Массив индивидуальных множителей для каждого ядра
  ; Расширенная информация
  StructVersion.i         ; Версия структуры данных из Core Temp
  TdpSupported.i          ; Флаг поддержки TDP данных
  PowerSupported.i        ; Флаг поддержки данных о мощности
  Array Tdp.i(0)          ; Массив TDP значений для каждого процессора в ваттах
  Array Power.f(0)        ; Массив потребляемой мощности для каждого ядра в ваттах
  ; Информация об ошибках
  LastError.i             ; Код последней ошибки (0 = успех)
  ErrorMessage.s          ; Текстовое описание последней ошибки
EndStructure


;- Variables
Global hCTLibrary.i = 0
Global GetCoreTempInfoAlt.ProtoGetCoreTempInfoAlt


;- Declares
Declare.i InitializeCoreTempInfo()
Declare.i GetCoreTempData(*Info.CORE_TEMP_INFO)
Declare FreeCoreTempInfo()



; Инициализация библиотеки GetCoreTempInfo
Procedure.i InitializeCoreTempInfo()
  Protected ArchDir$

  CompilerSelect #PB_Compiler_Processor
    CompilerCase #PB_Processor_x64
      ArchDir$ = "x64" + #PS$
    CompilerCase #PB_Processor_x86
      ArchDir$ = "x32" + #PS$
  CompilerEndSelect
  
  Protected LibName$  = "GetCoreTempInfo.dll"
  Protected PathProg$ = ArchDir$ + LibName$
  Protected PathRes$  = "res" + #PS$ + ArchDir$ + LibName$
  Protected PathDLL$
  
  If FileSize( PathProg$ ) > -1
    PathDLL$ = PathProg$
  ElseIf FileSize( PathRes$ ) > -1
    PathDLL$ = PathRes$
  ElseIf FileSize( LibName$ ) > -1
    PathDLL$ = LibName$
  Else
    MessageRequester( "Error", "Library file not found GetCoreTempInfo.dll" )
    ProcedureReturn 0
  EndIf
  
  hCTLibrary = OpenLibrary(#PB_Any, PathDLL$ )
  If hCTLibrary = 0
    ProcedureReturn 0
  EndIf
  
  ; Получаем указатель на функцию (используем Alt версию для совместимости)
  GetCoreTempInfoAlt = GetFunction(hCTLibrary, "fnGetCoreTempInfoAlt")
  If GetCoreTempInfoAlt = #Null
    CloseLibrary(hCTLibrary)
    hCTLibrary = 0
    ProcedureReturn 0
  EndIf
  
  ProcedureReturn hCTLibrary
EndProcedure



; Получение данных Core Temp
Procedure GetCoreTempData(*Info.CORE_TEMP_INFO)
  Protected *CoreTempData.CORE_TEMP_SHARED_DATA_EX
  Protected i.i, g.i, index.i
  Protected memorySize.i = SizeOf(CORE_TEMP_SHARED_DATA_EX)
  
  If hCTLibrary = 0 Or GetCoreTempInfoAlt = #Null
    *Info\LastError = -1
    *Info\ErrorMessage = "Core Temp library not initialized"
    ProcedureReturn #False
  EndIf
  
  ; Выделяем и обнуляем память для структуры
  *CoreTempData = AllocateMemory(memorySize)
  If *CoreTempData = 0
    *Info\LastError = -2
    *Info\ErrorMessage = "Memory allocation failed"
    ProcedureReturn #False
  EndIf
  
  FillMemory(*CoreTempData, memorySize, 0)
  
  ; Получаем данные из DLL
  If GetCoreTempInfoAlt(*CoreTempData)

    *Info\CPUName = PeekS(@*CoreTempData\sCPUName[0], -1, #PB_Ascii)
    
    ; Заполняем основную информацию
    *Info\CPUSpeed = *CoreTempData\fCPUSpeed
    *Info\FSBSpeed = *CoreTempData\fFSBSpeed
    *Info\Multiplier = *CoreTempData\fMultiplier
    *Info\VID = *CoreTempData\fVID
    *Info\CPUCount = *CoreTempData\uiCPUCnt
    *Info\CoreCount = *CoreTempData\uiCoreCnt
    *Info\IsFahrenheit = *CoreTempData\ucFahrenheit
    *Info\IsDistanceToTjMax = *CoreTempData\ucDeltaToTjMax
    
    ; Заполняем информацию о версии структуры
    *Info\StructVersion = *CoreTempData\uiStructVersion
    
    ; Заполняем информацию о поддержке расширенных функций
    *Info\TdpSupported = *CoreTempData\ucTdpSupported
    *Info\PowerSupported = *CoreTempData\ucPowerSupported
    
    ; Выделяем память для массивов
    If *CoreTempData\uiCPUCnt > 0 And *CoreTempData\uiCoreCnt > 0
      ; Основные массивы
      ReDim *Info\Temperatures(*CoreTempData\uiCPUCnt * *CoreTempData\uiCoreCnt - 1)
      ReDim *Info\Loads(*CoreTempData\uiCPUCnt * *CoreTempData\uiCoreCnt - 1)
      ReDim *Info\TjMax(*CoreTempData\uiCPUCnt - 1)
      
      ; Множители доступны только в версии 2+
      If *Info\StructVersion >= 2
        ReDim *Info\Multipliers(*CoreTempData\uiCPUCnt * *CoreTempData\uiCoreCnt - 1)
      Else
        ReDim *Info\Multipliers(0)
      EndIf
      
      ; Расширенные массивы (если поддерживаются и доступны в версии 2+)
      If *Info\StructVersion >= 2 And *Info\TdpSupported
        ReDim *Info\Tdp(*CoreTempData\uiCPUCnt - 1)
      Else
        ReDim *Info\Tdp(0)
      EndIf
      
      If *Info\StructVersion >= 2 And *Info\PowerSupported
        ReDim *Info\Power(*CoreTempData\uiCPUCnt * *CoreTempData\uiCoreCnt - 1)
      Else
        ReDim *Info\Power(0)
      EndIf
      
      ; Заполняем массивы данных
      For i = 0 To *CoreTempData\uiCPUCnt - 1
        ; TjMax для каждого CPU
        *Info\TjMax(i) = *CoreTempData\uiTjMax[i]
        
        ; TDP для каждого CPU (если поддерживается и доступна)
        If *Info\StructVersion >= 2 And *Info\TdpSupported
          *Info\Tdp(i) = *CoreTempData\uiTdp[i]
        EndIf
        
        ; Данные для каждого ядра
        For g = 0 To *CoreTempData\uiCoreCnt - 1
          index = g + (i * *CoreTempData\uiCoreCnt)
          
          ; Основные данные
          *Info\Temperatures(index) = *CoreTempData\fTemp[index]
          *Info\Loads(index) = *CoreTempData\uiLoad[index]
          
          ; Множители для каждого ядра (если доступны)
          If *Info\StructVersion >= 2
            *Info\Multipliers(index) = *CoreTempData\fMultipliers[index]
          EndIf
          
          ; Мощность для каждого ядра (если поддерживается и доступна)
          If *Info\StructVersion >= 2 And *Info\PowerSupported
            *Info\Power(index) = *CoreTempData\fPower[index]
          EndIf
        Next g
      Next i
    Else
      ; Если нет данных о CPU/ядрах, создаем пустые массивы
      ReDim *Info\Temperatures(0)
      ReDim *Info\Loads(0)
      ReDim *Info\TjMax(0)
      ReDim *Info\Multipliers(0)
      ReDim *Info\Tdp(0)
      ReDim *Info\Power(0)
    EndIf
    
    *Info\LastError = 0
    *Info\ErrorMessage = ""
    
    FreeMemory(*CoreTempData)
    ProcedureReturn #True
    
  Else
    ; Ошибка получения данных
    *Info\LastError = GetLastError_()
    
    If *Info\LastError = #UNKNOWN_EXCEPTION
      *Info\ErrorMessage = "Unknown exception occurred while copying shared memory"
    Else
      Protected Dim errMsg.w(100)
      FormatMessage_(#FORMAT_MESSAGE_FROM_SYSTEM, #Null, *Info\LastError, 0, @errMsg(0), 100, #Null)
      *Info\ErrorMessage = PeekS(@errMsg(0))
    EndIf
    
    FreeMemory(*CoreTempData)
    ProcedureReturn #False
  EndIf
EndProcedure

; Освобождение ресурсов
Procedure FreeCoreTempInfo()
  If hCTLibrary <> 0
    CloseLibrary(hCTLibrary)
    hCTLibrary = 0
    GetCoreTempInfoAlt = #Null
  EndIf
EndProcedure


; Процедура для автоматического определения периода обновления данных
Procedure.i DetectUpdateInterval()
  Protected previousData.CORE_TEMP_SHARED_DATA_EX
  Protected currentData.CORE_TEMP_SHARED_DATA_EX
  Protected startTime.i, endTime.i, sampleCount.i, totalTime.i
  Protected i.i, changesDetected.i, maxSamples.i = 10
  Protected tempSum1.f, tempSum2.f
  Protected detectedInterval.i
  
  ; Выделяем память для данных
  FillMemory(@previousData, SizeOf(CORE_TEMP_SHARED_DATA_EX), 0)
  FillMemory(@currentData, SizeOf(CORE_TEMP_SHARED_DATA_EX), 0)
  
  ; Получаем первые данные
  If GetCoreTempInfoAlt(@previousData) = 0
    ProcedureReturn 1000 ; Возвращаем значение по умолчанию при ошибке
  EndIf
  
  startTime = ElapsedMilliseconds()
  sampleCount = 0
  totalTime = 0
  
  Debug "Определение периода обновления Core Temp..."
  
  ; Собираем несколько образцов для определения периода
  While sampleCount < maxSamples
    Delay(50) ; Быстрый опрос каждые 50мс
    
    If GetCoreTempInfoAlt(@currentData)
      ; Проверяем изменения в данных
      changesDetected = #False
      
      ; Сравниваем температуры (основной показатель)
      For i = 0 To currentData\uiCPUCnt * currentData\uiCoreCnt - 1
        If i < 256 ; Защита от выхода за границы массива
          If Abs(currentData\fTemp[i] - previousData\fTemp[i]) > 0.1
            changesDetected = #True
            Break
          EndIf
        EndIf
      Next
      
      ; Если данные изменились, фиксируем время
      If changesDetected
        endTime = ElapsedMilliseconds()
        totalTime + (endTime - startTime)
        sampleCount + 1
        
        Debug "Образец " + Str(sampleCount) + ": изменение через " + Str(endTime - startTime) + "мс"
        
        ; Копируем текущие данные в предыдущие
        CopyMemory(@currentData, @previousData, SizeOf(CORE_TEMP_SHARED_DATA_EX))
        startTime = ElapsedMilliseconds()
      EndIf
    EndIf
  Wend
  
  ; Вычисляем средний период обновления
  If sampleCount > 0
    detectedInterval = totalTime / sampleCount
    Debug "Определенный период обновления: " + Str(detectedInterval) + "мс"
  Else
    detectedInterval = 1000 ; Значение по умолчанию
    Debug "Не удалось определить период, используется значение по умолчанию: 1000мс"
  EndIf
  
  ; Корректируем период для оптимальной работы
  If detectedInterval < 100
    detectedInterval = 100 ; Минимальный период 100мс
  ElseIf detectedInterval > 5000
    detectedInterval = 5000 ; Максимальный период 5 секунд
  EndIf
  
  ; Округляем до ближайших 100мс
  detectedInterval = Round(detectedInterval / 100, #PB_Round_Nearest) * 100
  
  Debug "Финальный период обновления: " + Str(detectedInterval) + "мс"
  ProcedureReturn detectedInterval
EndProcedure


; Вспомогательные математические процедуры
Procedure.i Min(a, b)
  If a < b
    ProcedureReturn a
  Else
    ProcedureReturn b
  EndIf
EndProcedure

Procedure.i Max(a, b)
  If a > b
    ProcedureReturn a
  Else
    ProcedureReturn b
  EndIf
EndProcedure


; Улучшенная версия с использованием нескольких метрик
Procedure.i DetectUpdateIntervalEx()
  Protected previousData.CORE_TEMP_SHARED_DATA_EX
  Protected currentData.CORE_TEMP_SHARED_DATA_EX
  Protected startTime.i, lastChangeTime.i
  Protected sampleCount.i, totalTime.i
  Protected maxSamples.i = 8
  Protected changesDetected.i
  Protected i.i, j.i
  
  ; Получаем начальные данные
  If GetCoreTempInfoAlt(@previousData) = 0
    ProcedureReturn 1000
  EndIf
  
  Debug "Расширенное определение периода обновления..."
  
  startTime = ElapsedMilliseconds()
  lastChangeTime = startTime
  sampleCount = 0
  totalTime = 0
  
  ; Мониторим изменения в течение 10 секунд максимум
  While sampleCount < maxSamples And (ElapsedMilliseconds() - startTime) < 10000
    Delay(30) ; Очень быстрый опрос для точного определения
    
    If GetCoreTempInfoAlt(@currentData)
      changesDetected = #False
      
      ; Проверяем несколько метрик для обнаружения изменений
      
      ; 1. Температуры
      For i = 0 To Min(currentData\uiCPUCnt * currentData\uiCoreCnt - 1, 255)
        If Abs(currentData\fTemp[i] - previousData\fTemp[i]) > 0.05
          changesDetected = #True
          Break 2
        EndIf
      Next
      
      ; 2. Загрузка процессора
      If Not changesDetected
        For i = 0 To Min(currentData\uiCPUCnt * currentData\uiCoreCnt - 1, 255)
          If Abs(currentData\uiLoad[i] - previousData\uiLoad[i]) > 1
            changesDetected = #True
            Break 2
          EndIf
        Next
      EndIf
      
      ; 3. Частота процессора (если доступна)
      If Not changesDetected And currentData\fCPUSpeed > 0
        If Abs(currentData\fCPUSpeed - previousData\fCPUSpeed) > 1.0
          changesDetected = #True
        EndIf
      EndIf
      
      ; Если обнаружены изменения, фиксируем время
      If changesDetected
        Protected currentTime.i = ElapsedMilliseconds()
        Protected interval.i = currentTime - lastChangeTime
        
        If interval >= 50 ; Игнорируем слишком короткие интервалы
          totalTime + interval
          sampleCount + 1
          
          Debug "Изменение " + Str(sampleCount) + " через " + Str(interval) + "мс"
          
          lastChangeTime = currentTime
          CopyMemory(@currentData, @previousData, SizeOf(CORE_TEMP_SHARED_DATA_EX))
        EndIf
      EndIf
    EndIf
  Wend
  
  ; Вычисляем результат
  Protected detectedInterval.i
  If sampleCount >= 3 ; Нужно минимум 3 образца для надежности
    detectedInterval = totalTime / sampleCount
    Debug "Средний период: " + Str(detectedInterval) + "мс на основе " + Str(sampleCount) + " образцов"
  Else
    detectedInterval = 1000
    Debug "Недостаточно данных, используется период по умолчанию: 1000мс"
  EndIf
  
  ; Корректируем и округляем
  detectedInterval = Max(100, Min(5000, detectedInterval))
  detectedInterval = Round(detectedInterval / 50, #PB_Round_Nearest) * 50
  
  Debug "Оптимальный период обновления: " + Str(detectedInterval) + "мс"
  ProcedureReturn detectedInterval
EndProcedure

; Процедура для интеллектуального обновления таймера
Procedure SmartUpdateTimer(WindowID.i, TimerID.i, *CurrentInterval.Integer)
  Protected newInterval.i
  
  ; Определяем новый период обновления
  newInterval = DetectUpdateIntervalEx()
  
  ; Если период значительно изменился, обновляем таймер
  If Abs(newInterval - *CurrentInterval\i) > 200 Or *CurrentInterval\i = 0
    Debug "Обновление таймера: " + Str(*CurrentInterval\i) + "мс -> " + Str(newInterval) + "мс"
    
    ; Удаляем старый таймер
    RemoveWindowTimer(WindowID, TimerID)
    
    ; Создаем новый таймер с оптимальным периодом
    AddWindowTimer(WindowID, TimerID, newInterval)
    
    ; Сохраняем новый период
    *CurrentInterval\i = newInterval
  EndIf
EndProcedure




;- Пример использования:
CompilerIf #PB_Compiler_IsMainFile
  
  
  ; Процедура IIf для строк
  Procedure.s IIf(Condition.i, TrueValue.s, FalseValue.s)
    If Condition
      ProcedureReturn TrueValue
    Else
      ProcedureReturn FalseValue
    EndIf
  EndProcedure
  
  
  
  Define Info.CORE_TEMP_INFO
  
  If InitializeCoreTempInfo()
    If GetCoreTempData(@Info)
      ; Используем данные...
      Debug "=== Данные Core Temp ==="
      Debug "Процессор: " + Info\CPUName
      Debug "Ядер на процессор: " + Str(Info\CoreCount)
      Debug "Количество процессоров: " + Str(Info\CPUCount)
      Debug "Версия структуры: " + Str(Info\StructVersion)
      Debug "Поддержка TDP: " + IIf(Info\TdpSupported, "Да", "Нет")
      Debug "Поддержка мощности: " + IIf(Info\PowerSupported, "Да", "Нет")
      Debug "Единицы температуры: " + IIf(Info\IsFahrenheit, "Фаренгейт", "Цельсий")
      Debug "Тип температуры: " + IIf(Info\IsDistanceToTjMax, "Расстояние до TjMax", "Фактическая температура")
      Debug "Напряжение VID: " + StrF(Info\VID, 4) + "В"
      Debug "Частота процессора: " + StrF(Info\CPUSpeed, 2) + " МГц"
      Debug "Частота шины: " + StrF(Info\FSBSpeed, 2) + " МГц"
      Debug "Множитель: " + StrF(Info\Multiplier, 2)
      Debug ""
      
      ; Вывод данных для всех процессоров и ядер
      Define cpu
      For cpu.i = 0 To Info\CPUCount - 1
        Debug "=== Процессор " + Str(cpu) + " ==="
        Debug "Tj.Max: " + Str(Info\TjMax(cpu)) + "°" + IIf(Info\IsFahrenheit, "F", "C")
        
        If Info\StructVersion >= 2 And Info\TdpSupported And ArraySize(Info\Tdp()) > cpu
          Debug "TDP: " + Str(Info\Tdp(cpu)) + "Вт"
        EndIf
        Debug ""
        
        ; Вывод данных для каждого ядра текущего процессора
        Define core
        For core.i = 0 To Info\CoreCount - 1
          Define index.i = core + (cpu * Info\CoreCount)
          
          Debug "Ядро " + Str(index) + ":"
          
          ; Температура
          If Info\IsDistanceToTjMax
            Debug "  Температура: " + StrF(Info\Temperatures(index), 2) + "°" + IIf(Info\IsFahrenheit, "F", "C") + " до TjMax"
          Else
            Debug "  Температура: " + StrF(Info\Temperatures(index), 2) + "°" + IIf(Info\IsFahrenheit, "F", "C")
          EndIf
          
          ; Нагрузка
          Debug "  Нагрузка: " + Str(Info\Loads(index)) + "%"
          
          ; Множитель (если доступен)
          If Info\StructVersion >= 2 And ArraySize(Info\Multipliers()) > index
            Debug "  Множитель: " + StrF(Info\Multipliers(index), 2)
          EndIf
          
          ; Мощность (если доступна)
          If Info\StructVersion >= 2 And Info\PowerSupported And ArraySize(Info\Power()) > index
            Debug "  Мощность: " + StrF(Info\Power(index), 2) + "Вт"
          EndIf
          
          Debug ""
        Next core
      Next cpu
      
      ; Сводная информация
      Debug "=== Сводная информация ==="
      Debug "Всего ядер: " + Str(Info\CPUCount * Info\CoreCount)
      
      ; Средняя температура и нагрузка
      If ArraySize(Info\Temperatures()) > 0
        Define avgTemp.f = 0.0
        Define avgLoad.f = 0.0
        Define coreCount.i = Info\CPUCount * Info\CoreCount
        
        Define i
        For i = 0 To coreCount - 1
          avgTemp + Info\Temperatures(i)
          avgLoad + Info\Loads(i)
        Next
        
        avgTemp / coreCount
        avgLoad / coreCount
        
        Debug "Средняя температура: " + StrF(avgTemp, 2) + "°" + IIf(Info\IsFahrenheit, "F", "C")
        Debug "Средняя нагрузка: " + StrF(avgLoad, 1) + "%"
      EndIf
      
      ; Максимальная температура и нагрузка
      If ArraySize(Info\Temperatures()) > 0
        Define maxTemp.f = Info\Temperatures(0)
        Define maxLoad.i = Info\Loads(0)
        Define maxTempCore.i = 0
        Define maxLoadCore.i = 0
        
        For i = 1 To ArraySize(Info\Temperatures()) - 1
          If Info\Temperatures(i) > maxTemp
            maxTemp = Info\Temperatures(i)
            maxTempCore = i
          EndIf
          If Info\Loads(i) > maxLoad
            maxLoad = Info\Loads(i)
            maxLoadCore = i
          EndIf
        Next
        
        Debug "Максимальная температура: " + StrF(maxTemp, 2) + "°" + IIf(Info\IsFahrenheit, "F", "C") + " (Ядро " + Str(maxTempCore) + ")"
        Debug "Максимальная нагрузка: " + Str(maxLoad) + "% (Ядро " + Str(maxLoadCore) + ")"
      EndIf
      
    Else
      Debug "Ошибка получения данных Core Temp:"
      Debug "Код ошибки: " + Str(Info\LastError)
      Debug "Сообщение: " + Info\ErrorMessage
    EndIf
    FreeCoreTempInfo()
  Else
    Debug "Не удалось инициализировать библиотеку Core Temp"
  EndIf
CompilerEndIf



; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 10
; Folding = ---
; EnableXP
; DPIAware
; EnablePurifier