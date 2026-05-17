#Requires AutoHotkey v2.0
#SingleInstance Force

; Ensure the script is DPI-aware to handle multi-monitor scaling correctly
; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
DllCall("SetThreadDpiAwarenessContext", "ptr", -4)

; Use Screen coordinates to ensure detection works even when game is not focused
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"

if !A_IsAdmin {
    Run '*RunAs "' A_ScriptFullPath '"'
    ExitApp
}

; Reference resolution (coordinates were captured at 3840x2160)
refW := 3840
refH := 2160

; Detect HTGame.exe window
gameTitle := "ahk_exe HTGame.exe"
if !WinExist(gameTitle) {
    MsgBox "HTGame.exe not found. Please launch the game first."
    ExitApp
}

; Get initial window state
WinGetClientPos(&winX, &winY, &winW, &winH, gameTitle)

; GUI Scaling factors (based on 3840x2160 reference)
scaleX := winW / refW
scaleY := winH / refH
guiW := Round(380 * scaleX)
guiH := Round(206 * scaleY)
fontSize := Round(14 * scaleY)

; Global variables for detection (Screen absolute)
abs_py := 0
abs_x1 := 0
abs_x2 := 0
abs_x3 := 0
abs_x4 := 0

; Target colors (RGB hex)
blueTarget   := 0x56EFFF
yellowTarget := 0xFFD684
redTarget    := 0xFA8272
purpleTarget := 0xFF86FF

; Color matching tolerance (0=exact, higher=more forgiving)
tolerance := 80

; Cooldown tracking in ms
cooldown := 150
lastPress1 := 0
lastPress2 := 0
lastPress3 := 0
lastPress4 := 0
wasActive1 := wasActive2 := wasActive3 := wasActive4 := false

; ---- Debug overlay window ----
; Added -DPIScale to prevent AHK from scaling the GUI coordinates automatically
debugGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20 -DPIScale")
debugGui.BackColor := "111111"
debugGui.SetFont("s" fontSize " cWhite", "Consolas")

; Add scaled controls
debugGui.Add("Text", "vLblBlue   x" Round(14*scaleX) " y" Round(10*scaleY)  " w" Round(320*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Blue:   --")
debugGui.Add("Text", "vLblYellow x" Round(14*scaleX) " y" Round(42*scaleY)  " w" Round(320*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Yellow: --")
debugGui.Add("Text", "vLblRed    x" Round(14*scaleX) " y" Round(74*scaleY)  " w" Round(320*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Red:    --")
debugGui.Add("Text", "vLblPurple x" Round(14*scaleX) " y" Round(106*scaleY) " w" Round(320*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Purple: --")
debugGui.Add("Text", "vLblRes    x" Round(14*scaleX) " y" Round(138*scaleY) " w" Round(340*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Res:    " winW "x" winH)

debugGui.SetFont("s" fontSize " cFF4444", "Consolas")
debugGui.Add("Text", "vLblStatus x" Round(14*scaleX) " y" Round(170*scaleY) " w" Round(340*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Status: STOPPED")

; Color swatches
swatchSize := Round(22 * scaleY)
debugGui.Add("Progress", "vSw1 x" Round(340*scaleX) " y" Round(12*scaleY)  " w" swatchSize " h" swatchSize " Background111111", 0)
debugGui.Add("Progress", "vSw2 x" Round(340*scaleX) " y" Round(44*scaleY)  " w" swatchSize " h" swatchSize " Background111111", 0)
debugGui.Add("Progress", "vSw3 x" Round(340*scaleX) " y" Round(76*scaleY)  " w" swatchSize " h" swatchSize " Background111111", 0)
debugGui.Add("Progress", "vSw4 x" Round(340*scaleX) " y" Round(108*scaleY) " w" swatchSize " h" swatchSize " Background111111", 0)

; Show GUI at the top-left of the game's client area
debugGui.Show("x" (winX + 10) " y" (winY + 10) " w" guiW " h" guiH " NoActivate")

; Initial coordinate update
UpdateCoords()

; Automatically track window movements every 1 second
SetTimer UpdateCoords, 1000

UpdateCoords() {
    global winX, winY, winW, winH, abs_py, abs_x1, abs_x2, abs_x3, abs_x4
    if !WinExist(gameTitle)
        return

    WinGetClientPos(&currX, &currY, &currW, &currH, gameTitle)
    
    ; Recalculate Screen-absolute detection coordinates
    abs_py := currY + Round(1684 * currH / refH)
    abs_x1 := currX + Round(878  * currW / refW)
    abs_x2 := currX + Round(1546 * currW / refW)
    abs_x3 := currX + Round(2270 * currW / refW)
    abs_x4 := currX + Round(2950 * currW / refW)

    ; If window moved or resized, update GUI position/size
    if (currX != winX || currY != winY || currW != winW || currH != winH) {
        winX := currX, winY := currY, winW := currW, winH := currH
        currentGuiW := Round(380 * (winW / refW))
        currentGuiH := Round(206 * (winH / refH))
        debugGui.Move(winX + 10, winY + 10, currentGuiW, currentGuiH)
        debugGui["LblRes"].Text := "Res:    " winW "x" winH
    }
}

; F1 to start, F2 to stop
F1:: {
    global
    UpdateCoords()
    debugGui["LblStatus"].Text := "Status: RUNNING"
    ToolTip "Color detection ON"
    SetTimer RemoveToolTip, -1500
    SetTimer CheckPixels, 10
}

F2:: {
    global
    SetTimer CheckPixels, 0
    debugGui["LblStatus"].Text := "Status: STOPPED"
    ToolTip "Color detection OFF"
    SetTimer RemoveToolTip, -1500
}

; Diagnostic hotkey to list controls
F3:: {
    if !WinExist(gameTitle)
        return
    controls := WinGetControls(gameTitle)
    controlList := ""
    for ctrl in controls
        controlList .= ctrl "`n"
    MsgBox "Controls found:`n" (controlList ? controlList : "None (Target top-level window)")
}

; Secret Sauce: Send WM_ACTIVATE before keys to trick the game into processing input
SendBackgroundKey(vk) {
    global gameTitle
    hwnd := WinExist(gameTitle)
    if !hwnd
        return

    ; WM_ACTIVATE = 0x0006, WA_ACTIVE = 1
    PostMessage(0x0006, 1, 0, , hwnd)

    ; Map Virtual Key to Scan Code
    sc := DllCall("MapVirtualKey", "UInt", vk, "UInt", 0, "UInt")
    
    ; LParamDown: ScanCode in bits 16-23, Repeat count 1
    lParamDown := (sc << 16) | 1
    ; LParamUp: Bits 30 & 31 set to 1, ScanCode in bits 16-23, Repeat count 1
    lParamUp := (sc << 16) | 1 | 0xC0000000

    PostMessage(0x0100, vk, lParamDown, , hwnd) ; WM_KEYDOWN
    Sleep(30)
    PostMessage(0x0101, vk, lParamUp, , hwnd)   ; WM_KEYUP
}

CheckPixels() {
    global
    now := A_TickCount
    
    ; Blue -> d (0x44)
    a1 := PixelSearch(&fX1, &fY1, abs_x1-1, abs_py-1, abs_x1+1, abs_py+1, blueTarget, tolerance)
    c1 := a1 ? PixelGetColor(fX1, fY1) : PixelGetColor(abs_x1, abs_py)
    if (a1 && !wasActive1 && now - lastPress1 > cooldown) {
        SendBackgroundKey(0x44)
        lastPress1 := now
    }
    wasActive1 := a1

    ; Yellow -> f (0x46)
    a2 := PixelSearch(&fX2, &fY2, abs_x2-1, abs_py-1, abs_x2+1, abs_py+1, yellowTarget, tolerance)
    c2 := a2 ? PixelGetColor(fX2, fY2) : PixelGetColor(abs_x2, abs_py)
    if (a2 && !wasActive2 && now - lastPress2 > cooldown) {
        SendBackgroundKey(0x46)
        lastPress2 := now
    }
    wasActive2 := a2

    ; Red -> j (0x4A)
    a3 := PixelSearch(&fX3, &fY3, abs_x3-1, abs_py-1, abs_x3+1, abs_py+1, redTarget, tolerance)
    c3 := a3 ? PixelGetColor(fX3, fY3) : PixelGetColor(abs_x3, abs_py)
    if (a3 && !wasActive3 && now - lastPress3 > cooldown) {
        SendBackgroundKey(0x4A)
        lastPress3 := now
    }
    wasActive3 := a3

    ; Purple -> k (0x4B)
    a4 := PixelSearch(&fX4, &fY4, abs_x4-1, abs_py-1, abs_x4+1, abs_py+1, purpleTarget, tolerance)
    c4 := a4 ? PixelGetColor(fX4, fY4) : PixelGetColor(abs_x4, abs_py)
    if (a4 && !wasActive4 && now - lastPress4 > cooldown) {
        SendBackgroundKey(0x4B)
        lastPress4 := now
    }
    wasActive4 := a4

    ; Update debug window swatches/labels
    m1 := a1 ? "MATCH" : "", m2 := a2 ? "MATCH" : "", m3 := a3 ? "MATCH" : "", m4 := a4 ? "MATCH" : ""
    debugGui["LblBlue"].Text   := "Blue:   " Format("0x{:06X}", c1) "  " m1
    debugGui["LblYellow"].Text := "Yellow: " Format("0x{:06X}", c2) "  " m2
    debugGui["LblRed"].Text    := "Red:    " Format("0x{:06X}", c3) "  " m3
    debugGui["LblPurple"].Text := "Purple: " Format("0x{:06X}", c4) "  " m4
    debugGui["Sw1"].Opt("Background" Format("{:06X}", c1))
    debugGui["Sw2"].Opt("Background" Format("{:06X}", c2))
    debugGui["Sw3"].Opt("Background" Format("{:06X}", c3))
    debugGui["Sw4"].Opt("Background" Format("{:06X}", c4))
}

RemoveToolTip() {
    ToolTip
}

F4::ExitApp
