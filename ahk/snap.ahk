#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; Smart Window Snap for 27" Display & YASB Integration
; ==============================================================================

; Отступ между окнами (в пикселях)
global GAP := 4

; Храним последнее состояние для циклического изменения размера (50% -> 33% -> 66%)
global LastAction := ""
global LastActionTime := 0
global CycleIndex := 0

GetWorkArea(&L, &T, &W, &H) {
    ; Получаем рабочую область монитора с учетом бара YASB
    MonitorGetWorkArea(1, &monL, &monT, &monR, &monB)
    L := monL + GAP
    T := monT + GAP
    W := (monR - monL) - (GAP * 2)
    H := (monB - monT) - (GAP * 2)
}

SnapActiveWindow(x, y, w, h) {
    hwnd := WinExist("A")
    if (!hwnd)
        return
    
    ; Снимаем нативный Maximize, если окно было распахнуто
    if (WinGetMinMax(hwnd) == 1)
        WinRestore(hwnd)
        
    WinMove(x, y, w, h, hwnd)

    ; Регистрируем окно в текущем воркспейсе Komorebi
    try {
        Run("komorebic.exe manage", , "Hide")
    }
}

; ------------------------------------------------------------------------------
; Alt + Left / Win + Left: Снап влево (50% -> 33% -> 66%)
; ------------------------------------------------------------------------------
!Left::
#Left::
{
    global LastAction, LastActionTime, CycleIndex, GAP
    GetWorkArea(&L, &T, &W, &H)
    
    now := A_TickCount
    if (LastAction == "Left" && (now - LastActionTime) < 1200) {
        CycleIndex := Mod(CycleIndex + 1, 3)
    } else {
        CycleIndex := 0
    }
    LastAction := "Left"
    LastActionTime := now
    
    if (CycleIndex == 0) {
        ; 50% Левая половина
        wHalf := (W - GAP) // 2
        SnapActiveWindow(L, T, wHalf, H)
    } else if (CycleIndex == 1) {
        ; 33.3% Левая треть (для 3 колонок на 27")
        wThird := (W - GAP * 2) // 3
        SnapActiveWindow(L, T, wThird, H)
    } else {
        ; 66.6% Две трети (Master окно слева)
        wTwoThirds := ((W - GAP * 2) * 2) // 3 + GAP
        SnapActiveWindow(L, T, wTwoThirds, H)
    }
}

; ------------------------------------------------------------------------------
; Alt + Right / Win + Right: Снап вправо (50% -> 33% -> 66%)
; ------------------------------------------------------------------------------
!Right::
#Right::
{
    global LastAction, LastActionTime, CycleIndex, GAP
    GetWorkArea(&L, &T, &W, &H)
    
    now := A_TickCount
    if (LastAction == "Right" && (now - LastActionTime) < 1200) {
        CycleIndex := Mod(CycleIndex + 1, 3)
    } else {
        CycleIndex := 0
    }
    LastAction := "Right"
    LastActionTime := now
    
    if (CycleIndex == 0) {
        ; 50% Правая половина
        wHalf := (W - GAP) // 2
        xRight := L + wHalf + GAP
        SnapActiveWindow(xRight, T, wHalf, H)
    } else if (CycleIndex == 1) {
        ; 33.3% Правая треть (для 3 колонок на 27")
        wThird := (W - GAP * 2) // 3
        xRight := L + (wThird + GAP) * 2
        SnapActiveWindow(xRight, T, wThird, H)
    } else {
        ; 66.6% Две трети справа
        wTwoThirds := ((W - GAP * 2) * 2) // 3 + GAP
        xRight := L + (W - wTwoThirds)
        SnapActiveWindow(xRight, T, wTwoThirds, H)
    }
}

; ------------------------------------------------------------------------------
; Alt + Up / Win + Up: Развернуть окно или Верхний квадрант
; ------------------------------------------------------------------------------
!Up::
#Up::
{
    global LastAction, GAP
    GetWorkArea(&L, &T, &W, &H)
    hwnd := WinExist("A")
    if (!hwnd)
        return

    WinGetPos(&winX, &winY, &winW, &winH, hwnd)
    hHalf := (H - GAP) // 2
    wHalf := (W - GAP) // 2

    ; Если окно уже прижато к левой половине -> переводим в верхний левый угол
    if (LastAction == "Left" || (winX <= L + 10 && winW <= wHalf + 20)) {
        SnapActiveWindow(L, T, wHalf, hHalf)
        LastAction := "TopLeft"
        return
    }
    ; Если окно уже прижато к правой половине -> переводим в верхний правый угол
    if (LastAction == "Right" || (winX >= L + wHalf - 10 && winW <= wHalf + 20)) {
        SnapActiveWindow(L + wHalf + GAP, T, wHalf, hHalf)
        LastAction := "TopRight"
        return
    }

    ; Иначе — полный экран под YASB
    SnapActiveWindow(L, T, W, H)
    LastAction := "Full"
}

; ------------------------------------------------------------------------------
; Alt + Down / Win + Down: Свернуть / Нижний квадрант
; ------------------------------------------------------------------------------
!Down::
#Down::
{
    global LastAction, GAP
    GetWorkArea(&L, &T, &W, &H)
    hwnd := WinExist("A")
    if (!hwnd)
        return

    WinGetPos(&winX, &winY, &winW, &winH, hwnd)
    hHalf := (H - GAP) // 2
    wHalf := (W - GAP) // 2
    yBottom := T + hHalf + GAP

    ; Если окно было слева -> переводим в нижний левый угол
    if (LastAction == "Left" || (winX <= L + 10 && winW <= wHalf + 20)) {
        SnapActiveWindow(L, yBottom, wHalf, hHalf)
        LastAction := "BottomLeft"
        return
    }
    ; Если окно было справа -> переводим в нижний правый угол
    if (LastAction == "Right" || (winX >= L + wHalf - 10 && winW <= wHalf + 20)) {
        SnapActiveWindow(L + wHalf + GAP, yBottom, wHalf, hHalf)
        LastAction := "BottomRight"
        return
    }

    ; Иначе — свернуть окно
    WinMinimize(hwnd)
    LastAction := "Min"
}

; ------------------------------------------------------------------------------
; Alt + C: Центральная треть (для 3 колонок на 27") или Центрирование
; ------------------------------------------------------------------------------
!c::
{
    global GAP
    GetWorkArea(&L, &T, &W, &H)
    wThird := (W - GAP * 2) // 3
    xCenter := L + wThird + GAP
    SnapActiveWindow(xCenter, T, wThird, H)
}

; ==============================================================================
; Воркспейсы / Профили (Alt + 1 .. 7)
; ==============================================================================
!1::Run("komorebic.exe focus-workspace 0", , "Hide")
!2::Run("komorebic.exe focus-workspace 1", , "Hide")
!3::Run("komorebic.exe focus-workspace 2", , "Hide")
!4::Run("komorebic.exe focus-workspace 3", , "Hide")
!5::Run("komorebic.exe focus-workspace 4", , "Hide")
!6::Run("komorebic.exe focus-workspace 5", , "Hide")
!7::Run("komorebic.exe focus-workspace 6", , "Hide")

; Перенос активного окна на рабочий стол (Alt + Shift + 1 .. 7)
!+1::Run("komorebic.exe move-to-workspace 0", , "Hide")
!+2::Run("komorebic.exe move-to-workspace 1", , "Hide")
!+3::Run("komorebic.exe move-to-workspace 2", , "Hide")
!+4::Run("komorebic.exe move-to-workspace 3", , "Hide")
!+5::Run("komorebic.exe move-to-workspace 4", , "Hide")
!+6::Run("komorebic.exe move-to-workspace 5", , "Hide")
!+7::Run("komorebic.exe move-to-workspace 6", , "Hide")

; Принудительно привязать окно к текущему столу
!m::Run("komorebic.exe manage", , "Hide")
