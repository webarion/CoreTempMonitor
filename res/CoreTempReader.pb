; Library for reading Core Temp data
; Author ...: Webarion
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
  uiLoad.l[256]           ; Load of each core in percent (0-100%), indexing: core + (processor * CoreCount)
  uiTjMax.l[128]          ; Maximum temperature for each processor (Tjunction Max) in degrees
  uiCoreCnt.l             ; Number of cores per processor
  uiCPUCnt.l              ; Number of physical processors in the system
  fTemp.f[256]            ; Temperature of each core, indexing: core + (processor * CoreCount)
  fVID.f                  ; CPU VID voltage (Voltage ID) in volts
  fCPUSpeed.f             ; Current CPU frequency in MHz
  fFSBSpeed.f             ; System bus frequency (FSB) in MHz
  fMultiplier.f           ; Overall CPU multiplier
  sCPUName.a[100]         ; CPU name (ASCII string)
  ucFahrenheit.a          ; Temperature units flag: 0=Celsius, 1=Fahrenheit
  ucDeltaToTjMax.a        ; Temperature type flag: 0=actual temperature, 1=distance to TjMax
  ; Extended fields (uiStructVersion = 2)
  ucTdpSupported.a        ; TDP support flag: 0=not supported, 1=supported
  ucPowerSupported.a      ; Power support flag: 0=not supported, 1=supported
  uiStructVersion.l       ; Data structure version (2 for this version)
  uiTdp.l[128]            ; TDP (Thermal Design Power) of each processor in watts
  fPower.f[128]           ; Power consumption of each core in watts, indexing: core + (processor * CoreCount)
  fMultipliers.f[256]     ; Individual multipliers for each core, indexing: core + (processor * CoreCount)
EndStructure

; Structure for convenient data access
Structure CORE_TEMP_INFO
  ; Basic information
  CPUName.s               ; CPU name
  CPUSpeed.f              ; Current CPU frequency in MHz
  FSBSpeed.f              ; System bus frequency in MHz
  Multiplier.f            ; Overall multiplier
  VID.f                   ; CPU VID voltage in volts
  CPUCount.i              ; Number of physical processors
  CoreCount.i             ; Number of cores per processor
  IsFahrenheit.i          ; Temperature units flag: 0=Celsius, 1=Fahrenheit
  IsDistanceToTjMax.i     ; Temperature type flag: 0=actual, 1=distance to TjMax
  ; Data arrays
  Array Temperatures.f(0) ; Array of temperatures of all cores in the system
  Array Loads.i(0)        ; Array of load of all cores in the system in percent
  Array TjMax.i(0)        ; Array of TjMax values for each processor
  Array Multipliers.f(0)  ; Array of individual multipliers for each core
  ; Extended information
  StructVersion.i         ; Data structure version from Core Temp
  TdpSupported.i          ; TDP data support flag
  PowerSupported.i        ; Power data support flag
  Array Tdp.i(0)          ; Array of TDP values for each processor in watts
  Array Power.f(0)        ; Array of power consumption for each core in watts
  ; Error information
  LastError.i             ; Last error code (0 = success)
  ErrorMessage.s          ; Text description of the last error
EndStructure


;- Variables
Global hCTLibrary.i = 0
Global GetCoreTempInfoAlt.ProtoGetCoreTempInfoAlt


;- Declares
Declare.i InitializeCoreTempInfo()
Declare.i GetCoreTempData(*Info.CORE_TEMP_INFO)
Declare FreeCoreTempInfo()



; GetCoreTempInfo library initialization
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
  
  ; Get function pointer (use Alt version for compatibility)
  GetCoreTempInfoAlt = GetFunction(hCTLibrary, "fnGetCoreTempInfoAlt")
  If GetCoreTempInfoAlt = #Null
    CloseLibrary(hCTLibrary)
    hCTLibrary = 0
    ProcedureReturn 0
  EndIf
  
  ProcedureReturn hCTLibrary
EndProcedure



; Core Temp data retrieval
Procedure GetCoreTempData(*Info.CORE_TEMP_INFO)
  Protected *CoreTempData.CORE_TEMP_SHARED_DATA_EX
  Protected i.i, g.i, index.i
  Protected memorySize.i = SizeOf(CORE_TEMP_SHARED_DATA_EX)
  
  If hCTLibrary = 0 Or GetCoreTempInfoAlt = #Null
    *Info\LastError = -1
    *Info\ErrorMessage = "Core Temp library not initialized"
    ProcedureReturn #False
  EndIf
  
  ; Allocate and zero memory for structure
  *CoreTempData = AllocateMemory(memorySize)
  If *CoreTempData = 0
    *Info\LastError = -2
    *Info\ErrorMessage = "Memory allocation failed"
    ProcedureReturn #False
  EndIf
  
  FillMemory(*CoreTempData, memorySize, 0)
  
  ; Get data from DLL
  If GetCoreTempInfoAlt(*CoreTempData)

    *Info\CPUName = PeekS(@*CoreTempData\sCPUName[0], -1, #PB_Ascii)
    
    ; Fill basic information
    *Info\CPUSpeed = *CoreTempData\fCPUSpeed
    *Info\FSBSpeed = *CoreTempData\fFSBSpeed
    *Info\Multiplier = *CoreTempData\fMultiplier
    *Info\VID = *CoreTempData\fVID
    *Info\CPUCount = *CoreTempData\uiCPUCnt
    *Info\CoreCount = *CoreTempData\uiCoreCnt
    *Info\IsFahrenheit = *CoreTempData\ucFahrenheit
    *Info\IsDistanceToTjMax = *CoreTempData\ucDeltaToTjMax
    
    ; Fill structure version information
    *Info\StructVersion = *CoreTempData\uiStructVersion
    
    ; Fill extended functions support information
    *Info\TdpSupported = *CoreTempData\ucTdpSupported
    *Info\PowerSupported = *CoreTempData\ucPowerSupported
    
    ; Allocate memory for arrays
    If *CoreTempData\uiCPUCnt > 0 And *CoreTempData\uiCoreCnt > 0
      ; Main arrays
      ReDim *Info\Temperatures(*CoreTempData\uiCPUCnt * *CoreTempData\uiCoreCnt - 1)
      ReDim *Info\Loads(*CoreTempData\uiCPUCnt * *CoreTempData\uiCoreCnt - 1)
      ReDim *Info\TjMax(*CoreTempData\uiCPUCnt - 1)
      
      ; Multipliers available only in version 2+
      If *Info\StructVersion >= 2
        ReDim *Info\Multipliers(*CoreTempData\uiCPUCnt * *CoreTempData\uiCoreCnt - 1)
      Else
        ReDim *Info\Multipliers(0)
      EndIf
      
      ; Extended arrays (if supported and available in version 2+)
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
      
      ; Fill data arrays
      For i = 0 To *CoreTempData\uiCPUCnt - 1
        ; TjMax for each CPU
        *Info\TjMax(i) = *CoreTempData\uiTjMax[i]
        
        ; TDP for each CPU (if supported and available)
        If *Info\StructVersion >= 2 And *Info\TdpSupported
          *Info\Tdp(i) = *CoreTempData\uiTdp[i]
        EndIf
        
        ; Data for each core
        For g = 0 To *CoreTempData\uiCoreCnt - 1
          index = g + (i * *CoreTempData\uiCoreCnt)
          
          ; Basic data
          *Info\Temperatures(index) = *CoreTempData\fTemp[index]
          *Info\Loads(index) = *CoreTempData\uiLoad[index]
          
          ; Multipliers for each core (if available)
          If *Info\StructVersion >= 2
            *Info\Multipliers(index) = *CoreTempData\fMultipliers[index]
          EndIf
          
          ; Power for each core (if supported and available)
          If *Info\StructVersion >= 2 And *Info\PowerSupported
            *Info\Power(index) = *CoreTempData\fPower[index]
          EndIf
        Next g
      Next i
    Else
      ; If no CPU/core data, create empty arrays
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
    ; Data retrieval error
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

; Resource cleanup
Procedure FreeCoreTempInfo()
  If hCTLibrary <> 0
    CloseLibrary(hCTLibrary)
    hCTLibrary = 0
    GetCoreTempInfoAlt = #Null
  EndIf
EndProcedure


; Procedure for automatic detection of data update interval
Procedure.i DetectUpdateInterval()
  Protected previousData.CORE_TEMP_SHARED_DATA_EX
  Protected currentData.CORE_TEMP_SHARED_DATA_EX
  Protected startTime.i, endTime.i, sampleCount.i, totalTime.i
  Protected i.i, changesDetected.i, maxSamples.i = 10
  Protected tempSum1.f, tempSum2.f
  Protected detectedInterval.i
  
  ; Allocate memory for data
  FillMemory(@previousData, SizeOf(CORE_TEMP_SHARED_DATA_EX), 0)
  FillMemory(@currentData, SizeOf(CORE_TEMP_SHARED_DATA_EX), 0)
  
  ; Get first data
  If GetCoreTempInfoAlt(@previousData) = 0
    ProcedureReturn 1000 ; Return default value on error
  EndIf
  
  startTime = ElapsedMilliseconds()
  sampleCount = 0
  totalTime = 0
  
  Debug "Detecting Core Temp update interval..."
  
  ; Collect several samples to determine interval
  While sampleCount < maxSamples
    Delay(50) ; Fast polling every 50ms
    
    If GetCoreTempInfoAlt(@currentData)
      ; Check for data changes
      changesDetected = #False
      
      ; Compare temperatures (main indicator)
      For i = 0 To currentData\uiCPUCnt * currentData\uiCoreCnt - 1
        If i < 256 ; Array bounds protection
          If Abs(currentData\fTemp[i] - previousData\fTemp[i]) > 0.1
            changesDetected = #True
            Break
          EndIf
        EndIf
      Next
      
      ; If data changed, record time
      If changesDetected
        endTime = ElapsedMilliseconds()
        totalTime + (endTime - startTime)
        sampleCount + 1
        
        Debug "Sample " + Str(sampleCount) + ": change after " + Str(endTime - startTime) + "ms"
        
        ; Copy current data to previous
        CopyMemory(@currentData, @previousData, SizeOf(CORE_TEMP_SHARED_DATA_EX))
        startTime = ElapsedMilliseconds()
      EndIf
    EndIf
  Wend
  
  ; Calculate average update interval
  If sampleCount > 0
    detectedInterval = totalTime / sampleCount
    Debug "Detected update interval: " + Str(detectedInterval) + "ms"
  Else
    detectedInterval = 1000 ; Default value
    Debug "Failed to detect interval, using default: 1000ms"
  EndIf
  
  ; Adjust interval for optimal performance
  If detectedInterval < 100
    detectedInterval = 100 ; Minimum period 100ms
  ElseIf detectedInterval > 5000
    detectedInterval = 5000 ; Maximum period 5 seconds
  EndIf
  
  ; Round to nearest 100ms
  detectedInterval = Round(detectedInterval / 100, #PB_Round_Nearest) * 100
  
  Debug "Final update interval: " + Str(detectedInterval) + "ms"
  ProcedureReturn detectedInterval
EndProcedure


; Helper math procedures
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


; Enhanced version using multiple metrics
Procedure.i DetectUpdateIntervalEx()
  Protected previousData.CORE_TEMP_SHARED_DATA_EX
  Protected currentData.CORE_TEMP_SHARED_DATA_EX
  Protected startTime.i, lastChangeTime.i
  Protected sampleCount.i, totalTime.i
  Protected maxSamples.i = 8
  Protected changesDetected.i
  Protected i.i, j.i
  
  ; Get initial data
  If GetCoreTempInfoAlt(@previousData) = 0
    ProcedureReturn 1000
  EndIf
  
  Debug "Extended update interval detection..."
  
  startTime = ElapsedMilliseconds()
  lastChangeTime = startTime
  sampleCount = 0
  totalTime = 0
  
  ; Monitor changes for maximum 10 seconds
  While sampleCount < maxSamples And (ElapsedMilliseconds() - startTime) < 10000
    Delay(30) ; Very fast polling for accurate detection
    
    If GetCoreTempInfoAlt(@currentData)
      changesDetected = #False
      
      ; Check multiple metrics for change detection
      
      ; 1. Temperatures
      For i = 0 To Min(currentData\uiCPUCnt * currentData\uiCoreCnt - 1, 255)
        If Abs(currentData\fTemp[i] - previousData\fTemp[i]) > 0.05
          changesDetected = #True
          Break 2
        EndIf
      Next
      
      ; 2. CPU load
      If Not changesDetected
        For i = 0 To Min(currentData\uiCPUCnt * currentData\uiCoreCnt - 1, 255)
          If Abs(currentData\uiLoad[i] - previousData\uiLoad[i]) > 1
            changesDetected = #True
            Break 2
          EndIf
        Next
      EndIf
      
      ; 3. CPU frequency (if available)
      If Not changesDetected And currentData\fCPUSpeed > 0
        If Abs(currentData\fCPUSpeed - previousData\fCPUSpeed) > 1.0
          changesDetected = #True
        EndIf
      EndIf
      
      ; If changes detected, record time
      If changesDetected
        Protected currentTime.i = ElapsedMilliseconds()
        Protected interval.i = currentTime - lastChangeTime
        
        If interval >= 50 ; Ignore too short intervals
          totalTime + interval
          sampleCount + 1
          
          Debug "Change " + Str(sampleCount) + " after " + Str(interval) + "ms"
          
          lastChangeTime = currentTime
          CopyMemory(@currentData, @previousData, SizeOf(CORE_TEMP_SHARED_DATA_EX))
        EndIf
      EndIf
    EndIf
  Wend
  
  ; Calculate result
  Protected detectedInterval.i
  If sampleCount >= 3 ; Need minimum 3 samples for reliability
    detectedInterval = totalTime / sampleCount
    Debug "Average interval: " + Str(detectedInterval) + "ms based on " + Str(sampleCount) + " samples"
  Else
    detectedInterval = 1000
    Debug "Insufficient data, using default interval: 1000ms"
  EndIf
  
  ; Adjust and round
  detectedInterval = Max(100, Min(5000, detectedInterval))
  detectedInterval = Round(detectedInterval / 50, #PB_Round_Nearest) * 50
  
  Debug "Optimal update interval: " + Str(detectedInterval) + "ms"
  ProcedureReturn detectedInterval
EndProcedure

; Procedure for intelligent timer update
Procedure SmartUpdateTimer(WindowID.i, TimerID.i, *CurrentInterval.Integer)
  Protected newInterval.i
  
  ; Determine new update interval
  newInterval = DetectUpdateIntervalEx()
  
  ; If interval changed significantly, update timer
  If Abs(newInterval - *CurrentInterval\i) > 200 Or *CurrentInterval\i = 0
    Debug "Updating timer: " + Str(*CurrentInterval\i) + "ms -> " + Str(newInterval) + "ms"
    
    ; Remove old timer
    RemoveWindowTimer(WindowID, TimerID)
    
    ; Create new timer with optimal interval
    AddWindowTimer(WindowID, TimerID, newInterval)
    
    ; Save new interval
    *CurrentInterval\i = newInterval
  EndIf
EndProcedure




;- Usage example:
CompilerIf #PB_Compiler_IsMainFile
  
  
  ; IIf procedure for strings
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
      ; Use data...
      Debug "=== Core Temp Data ==="
      Debug "CPU: " + Info\CPUName
      Debug "Cores per processor: " + Str(Info\CoreCount)
      Debug "Number of processors: " + Str(Info\CPUCount)
      Debug "Structure version: " + Str(Info\StructVersion)
      Debug "TDP support: " + IIf(Info\TdpSupported, "Yes", "No")
      Debug "Power support: " + IIf(Info\PowerSupported, "Yes", "No")
      Debug "Temperature units: " + IIf(Info\IsFahrenheit, "Fahrenheit", "Celsius")
      Debug "Temperature type: " + IIf(Info\IsDistanceToTjMax, "Distance to TjMax", "Actual temperature")
      Debug "VID voltage: " + StrF(Info\VID, 4) + "V"
      Debug "CPU frequency: " + StrF(Info\CPUSpeed, 2) + " MHz"
      Debug "Bus frequency: " + StrF(Info\FSBSpeed, 2) + " MHz"
      Debug "Multiplier: " + StrF(Info\Multiplier, 2)
      Debug ""
      
      ; Output data for all processors and cores
      Define cpu
      For cpu.i = 0 To Info\CPUCount - 1
        Debug "=== Processor " + Str(cpu) + " ==="
        Debug "Tj.Max: " + Str(Info\TjMax(cpu)) + "°" + IIf(Info\IsFahrenheit, "F", "C")
        
        If Info\StructVersion >= 2 And Info\TdpSupported And ArraySize(Info\Tdp()) > cpu
          Debug "TDP: " + Str(Info\Tdp(cpu)) + "W"
        EndIf
        Debug ""
        
        ; Output data for each core of current processor
        Define core
        For core.i = 0 To Info\CoreCount - 1
          Define index.i = core + (cpu * Info\CoreCount)
          
          Debug "Core " + Str(index) + ":"
          
          ; Temperature
          If Info\IsDistanceToTjMax
            Debug "  Temperature: " + StrF(Info\Temperatures(index), 2) + "°" + IIf(Info\IsFahrenheit, "F", "C") + " to TjMax"
          Else
            Debug "  Temperature: " + StrF(Info\Temperatures(index), 2) + "°" + IIf(Info\IsFahrenheit, "F", "C")
          EndIf
          
          ; Load
          Debug "  Load: " + Str(Info\Loads(index)) + "%"
          
          ; Multiplier (if available)
          If Info\StructVersion >= 2 And ArraySize(Info\Multipliers()) > index
            Debug "  Multiplier: " + StrF(Info\Multipliers(index), 2)
          EndIf
          
          ; Power (if available)
          If Info\StructVersion >= 2 And Info\PowerSupported And ArraySize(Info\Power()) > index
            Debug "  Power: " + StrF(Info\Power(index), 2) + "W"
          EndIf
          
          Debug ""
        Next core
      Next cpu
      
      ; Summary information
      Debug "=== Summary Information ==="
      Debug "Total cores: " + Str(Info\CPUCount * Info\CoreCount)
      
      ; Average temperature and load
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
        
        Debug "Average temperature: " + StrF(avgTemp, 2) + "°" + IIf(Info\IsFahrenheit, "F", "C")
        Debug "Average load: " + StrF(avgLoad, 1) + "%"
      EndIf
      
      ; Maximum temperature and load
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
        
        Debug "Maximum temperature: " + StrF(maxTemp, 2) + "°" + IIf(Info\IsFahrenheit, "F", "C") + " (Core " + Str(maxTempCore) + ")"
        Debug "Maximum load: " + Str(maxLoad) + "% (Core " + Str(maxLoadCore) + ")"
      EndIf
      
    Else
      Debug "Core Temp data retrieval error:"
      Debug "Error code: " + Str(Info\LastError)
      Debug "Message: " + Info\ErrorMessage
    EndIf
    FreeCoreTempInfo()
  Else
    Debug "Failed to initialize Core Temp library"
  EndIf
CompilerEndIf
