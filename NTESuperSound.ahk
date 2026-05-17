#Requires AutoHotkey v2.0
#SingleInstance Force

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

; Get window client area position and size
WinGetClientPos(&winX, &winY, &winW, &winH, gameTitle)

; Scale pixel coordinates relative to game window
py := winY + Round(1684 * winH / refH)
x1 := winX + Round(878  * winW / refW)   ; blue   -> d
x2 := winX + Round(1546 * winW / refW)   ; yellow -> f
x3 := winX + Round(2270 * winW / refW)   ; red    -> j
x4 := winX + Round(2950 * winW / refW)   ; purple -> k

; Target colors (RGB hex)
blueTarget   := 0x56EFFF
yellowTarget := 0xFFD684
redTarget    := 0xFA8272
purpleTarget := 0xFF86FF

; Color matching tolerance (0=exact, higher=more forgiving)
tolerance := 80

; Track previous state to avoid key repeats
wasActive1 := false
wasActive2 := false
wasActive3 := false
wasActive4 := false

; Cooldown tracking in ms
cooldown := 150
lastPress1 := 0
lastPress2 := 0
lastPress3 := 0
lastPress4 := 0

; ---- Debug overlay window ----
debugGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20")
debugGui.BackColor := "111111"
debugGui.SetFont("s14 cWhite", "Consolas")
debugGui.Add("Text", "vLblBlue   x14  y10  w320 h28 BackgroundTrans", "Blue:   --")
debugGui.Add("Text", "vLblYellow x14  y42  w320 h28 BackgroundTrans", "Yellow: --")
debugGui.Add("Text", "vLblRed    x14  y74  w320 h28 BackgroundTrans", "Red:    --")
debugGui.Add("Text", "vLblPurple x14  y106 w320 h28 BackgroundTrans", "Purple: --")
; Resolution label
debugGui.Add("Text", "vLblRes    x14  y138 w340 h28 BackgroundTrans", "Res:    " winW "x" winH)
; Status label
debugGui.SetFont("s14 cFF4444", "Consolas")
debugGui.Add("Text", "vLblStatus x14  y170 w340 h28 BackgroundTrans", "Status: STOPPED")
debugGui.SetFont("s14 cWhite", "Consolas")
; Color swatches
debugGui.Add("Progress", "vSw1 x340 y12  w22 h22 Background111111", 0)
debugGui.Add("Progress", "vSw2 x340 y44  w22 h22 Background111111", 0)
debugGui.Add("Progress", "vSw3 x340 y76  w22 h22 Background111111", 0)
debugGui.Add("Progress", "vSw4 x340 y108 w22 h22 Background111111", 0)
debugGui.Show("x10 y10 w380 h206 NoActivate")
debugGui.Title := "Color Monitor"

; F1 to start, F2 to stop
F1:: {
    global
    if !WinExist(gameTitle) {
        ToolTip "HTGame.exe not found!"
        SetTimer RemoveToolTip, -1500
        return
    }
    ; Recalculate coordinates in case window moved/resized
    WinGetClientPos(&winX, &winY, &winW, &winH, gameTitle)
    py := winY + Round(1684 * winH / refH)
    x1 := winX + Round(878  * winW / refW)
    x2 := winX + Round(1546 * winW / refW)
    x3 := winX + Round(2270 * winW / refW)
    x4 := winX + Round(2950 * winW / refW)
    debugGui["LblRes"].Text := "Res:    " winW "x" winH
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

CheckPixels() {
    global
    now := A_TickCount

    ; Blue -> d
    c1 := PixelGetColor(x1, py)
    a1 := ColorMatch(c1, blueTarget, tolerance)
    if (a1 && !wasActive1 && now - lastPress1 > cooldown) {
        Send "d"
        lastPress1 := now
    }
    wasActive1 := a1

    ; Yellow -> f
    c2 := PixelGetColor(x2, py)
    a2 := ColorMatch(c2, yellowTarget, tolerance)
    if (a2 && !wasActive2 && now - lastPress2 > cooldown) {
        Send "f"
        lastPress2 := now
    }
    wasActive2 := a2

    ; Red -> j
    c3 := PixelGetColor(x3, py)
    a3 := ColorMatch(c3, redTarget, tolerance)
    if (a3 && !wasActive3 && now - lastPress3 > cooldown) {
        Send "j"
        lastPress3 := now
    }
    wasActive3 := a3

    ; Purple -> k
    c4 := PixelGetColor(x4, py)
    a4 := ColorMatch(c4, purpleTarget, tolerance)
    if (a4 && !wasActive4 && now - lastPress4 > cooldown) {
        Send "k"
        lastPress4 := now
    }
    wasActive4 := a4

    ; Update debug window
    m1 := a1 ? "MATCH" : ""
    m2 := a2 ? "MATCH" : ""
    m3 := a3 ? "MATCH" : ""
    m4 := a4 ? "MATCH" : ""
    debugGui["LblBlue"].Text   := "Blue:   " Format("0x{:06X}", c1) "  " m1
    debugGui["LblYellow"].Text := "Yellow: " Format("0x{:06X}", c2) "  " m2
    debugGui["LblRed"].Text    := "Red:    " Format("0x{:06X}", c3) "  " m3
    debugGui["LblPurple"].Text := "Purple: " Format("0x{:06X}", c4) "  " m4

    ; Update swatch colors
    debugGui["Sw1"].Opt("Background" Format("{:06X}", c1))
    debugGui["Sw2"].Opt("Background" Format("{:06X}", c2))
    debugGui["Sw3"].Opt("Background" Format("{:06X}", c3))
    debugGui["Sw4"].Opt("Background" Format("{:06X}", c4))
}

ColorMatch(pixel, target, tol) {
    pr := (pixel >> 16) & 0xFF
    pg := (pixel >> 8) & 0xFF
    pb := pixel & 0xFF
    tr := (target >> 16) & 0xFF
    tg := (target >> 8) & 0xFF
    tb := target & 0xFF
    return (Abs(pr - tr) <= tol && Abs(pg - tg) <= tol && Abs(pb - tb) <= tol)
}

RemoveToolTip() {
    ToolTip
}

F4::ExitApp
