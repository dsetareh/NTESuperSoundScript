#Requires AutoHotkey v2.0
#SingleInstance Force

; Ensure the script is DPI-aware to handle multi-monitor scaling correctly
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
guiScale := 2
scaleX := (winW / refW) * guiScale
scaleY := (winH / refH) * guiScale
guiW := Round(380 * scaleX)
guiH := Round(180 * scaleY)
fontSize := Round(14 * scaleY)

; Global variables for detection (Screen absolute)
abs_py := 0
abs_x1 := 0
abs_x2 := 0
abs_x3 := 0
abs_x4 := 0

; Target colors (RGB format)
blueTarget   := 0x56EFFF
yellowTarget := 0xFFD684
redTarget    := 0xFA8272
purpleTarget := 0xFF86FF

; Song Completed screen colors (at key positions)
completedColors := [0x56392B, 0x593F30, 0x573A2C, 0x56392B]

; Lane-specific tolerances
blueTolerance := 80
yellowTolerance := 80
redTolerance := 80
purpleTolerance := 80


; Cooldown tracking in ms (Independent per color)
cooldown := 120
lastPress := [0, 0, 0, 0]
wasActive := [false, false, false, false]
isRunning := false
isMenu := false
menuStartTime := 0
lastKeyText := "--"

; ---- Debug overlay window ----
; Added -DPIScale to prevent AHK from scaling the GUI coordinates automatically
debugGui := Gui("+AlwaysOnTop +ToolWindow -Caption +E0x20 -DPIScale")
debugGui.BackColor := "111111"
debugGui.SetFont("s" fontSize " cWhite", "Consolas")

; Swatch dimensions
swW := Round(85 * scaleX)
swH := Round(28 * scaleY)
swGap := Round(5 * scaleX)

; Add swatches in a single row
debugGui.Add("Progress", "vSw1 x" Round(14*scaleX) " y" Round(10*scaleY) " w" swW " h" swH " Background111111", 0)
debugGui.Add("Progress", "vSw2 x" Round(14*scaleX + (swW + swGap)) " y" Round(10*scaleY) " w" swW " h" swH " Background111111", 0)
debugGui.Add("Progress", "vSw3 x" Round(14*scaleX + 2*(swW + swGap)) " y" Round(10*scaleY) " w" swW " h" swH " Background111111", 0)
debugGui.Add("Progress", "vSw4 x" Round(14*scaleX + 3*(swW + swGap)) " y" Round(10*scaleY) " w" swW " h" swH " Background111111", 0)

; Add other controls moved up
debugGui.Add("Text", "vLblRes    x" Round(14*scaleX) " y" Round(45*scaleY) " w" Round(340*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Res:    " winW "x" winH)
debugGui.Add("Text", "vLblScreen x" Round(14*scaleX) " y" Round(77*scaleY) " w" Round(340*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Screen: --")

debugGui.SetFont("s" fontSize " cFF4444", "Consolas")
debugGui.Add("Text", "vLblStatus x" Round(14*scaleX) " y" Round(141*scaleY) " w" Round(340*scaleX) " h" Round(28*scaleY) " BackgroundTrans", "Status: STOPPED")

; Show GUI at the top-left of the game's client area
debugGui.Show("x" (winX + 10) " y" (winY + 10) " w" guiW " h" Round(180 * scaleY) " NoActivate")

; Initial coordinate update
UpdateCoords()

; Automatically track window movements every 1 second
SetTimer UpdateCoords, 5000

UpdateCoords() {
    global winX, winY, winW, winH, abs_py, abs_x1, abs_x2, abs_x3, abs_x4, isMenu, menuStartTime, isRunning
    if !WinExist(gameTitle)
        return

    WinGetClientPos(&currX, &currY, &currW, &currH, gameTitle)
    
    ; Recalculate Screen-absolute detection coordinates
    abs_py := currY + Round(1684 * currH / refH)
    abs_x1 := currX + Round(878  * currW / refW)
    abs_x2 := currX + Round(1546 * currW / refW)
    abs_x3 := currX + Round(2270 * currW / refW)
    abs_x4 := currX + Round(2950 * currW / refW)

    ; Screen Detection (Pink bar landmark)
    pinkRGB := 0xBB2967
    variance := 0x10
    mY  := currY + Round(1866 * currH / refH) ; Coord 622 in 720p
    mX1 := currX + Round(400  * currW / refW)
    mX2 := currX + Round(1920 * currW / refW)
    mX3 := currX + Round(3440 * currW / refW)

    ; Check 3 points along the line to confirm the pink bar is present
    isMenu := PixelSearch(&_, &_, mX1-5, mY-5, mX1+5, mY+5, pinkRGB, variance) 
           && PixelSearch(&_, &_, mX2-5, mY-5, mX2+5, mY+5, pinkRGB, variance) 
           && PixelSearch(&_, &_, mX3-5, mY-5, mX3+5, mY+5, pinkRGB, variance)
    
    ; Handle 5s auto-play logic
    if (isRunning && isMenu) {
        if (menuStartTime == 0) {
            menuStartTime := A_TickCount
        } else if (A_TickCount - menuStartTime > 5000) {
            ; ClickPlay()
            menuStartTime := A_TickCount ; Reset timer to avoid spamming if menu persists
        }
    } else {
        menuStartTime := 0
    }

    debugGui["LblScreen"].Text := "Screen: " (isMenu ? "MENU" : "GAME")

    ; If window moved or resized, update GUI position/size
    if (currX != winX || currY != winY || currW != winW || currH != winH) {
        winX := currX, winY := currY, winW := currW, winH := currH
        currentGuiW := Round(380 * (winW / refW) * guiScale)
        currentGuiH := Round(180 * (winH / refH) * guiScale)
        debugGui.Move(winX + 10, winY + 10, currentGuiW, currentGuiH)
        debugGui["LblRes"].Text := "Res:    " winW "x" winH
    }
}

; F1 to start, F2 to stop
F1:: {
    global
    isRunning := true
    UpdateCoords()
    debugGui["LblStatus"].Text := "Status: RUNNING"
    ToolTip "Color detection ON"
    SetTimer RemoveToolTip, -1500
    SetTimer CheckPixels, 15
}

F2:: {
    global
    isRunning := false
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
SendBackgroundKey(vk, keyChar) {
    global gameTitle, lastKeyText
    hwnd := WinExist(gameTitle)
    if !hwnd
        return

    ; WM_ACTIVATE = 0x0006, WA_ACTIVE = 1
    PostMessage(0x0006, 1, 0, , hwnd)

    ; Map Virtual Key to Scan Code
    sc := DllCall("MapVirtualKey", "UInt", vk, "UInt", 0, "UInt")
    
    ; LParamDown: ScanCode in bits 16-23, Repeat count 1
    lParamDown := (sc << 16) | 1
    
    lastKeyText := keyChar " (" A_TickCount ")"

    PostMessage(0x0100, vk, lParamDown, , hwnd) ; WM_KEYDOWN
    
    ; Schedule KeyUp after 10ms (non-blocking)
    SetTimer () => PostKeyUp(hwnd, vk, sc), -10
}

PostKeyUp(hwnd, vk, sc) {
    ; WM_ACTIVATE = 0x0006, WA_ACTIVE = 1
    PostMessage(0x0006, 1, 0, , hwnd)
    ; LParamUp: Bits 30 & 31 set to 1, ScanCode in bits 16-23, Repeat count 1
    lParamUp := (sc << 16) | 1 | 0xC0000000
    PostMessage(0x0101, vk, lParamUp, , hwnd)   ; WM_KEYUP
}


CheckPixels() {
    global
    now := A_TickCount
    
    ; Read center pixels first for completed-screen check and debug display
    c1 := PixelGetColor(abs_x1, abs_py)
    c2 := PixelGetColor(abs_x2, abs_py)
    c3 := PixelGetColor(abs_x3, abs_py)
    c4 := PixelGetColor(abs_x4, abs_py)

    ; Skip if on menu screen
    if (isMenu) {
        return
    }

    ; Skip if Song Completed screen detected (all 4 positions match completed colors)
    completedTol := 25
    if (ColorMatch(c1, completedColors[1], completedTol)
        && ColorMatch(c2, completedColors[2], completedTol)
        && ColorMatch(c3, completedColors[3], completedTol)
        && ColorMatch(c4, completedColors[4], completedTol)) {
        debugGui["LblScreen"].Text := "Screen: COMPLETED"
        return
    }

    hit := false
    ; Blue -> d (0x44)
    a1 := (now - lastPress[1] > cooldown) ? ColorMatch(c1, blueTarget, blueTolerance) : wasActive[1]
    if (a1 && !wasActive[1]) {
        SendBackgroundKey(0x44, "D")
        lastPress[1] := now
        hit := true
    }
    wasActive[1] := a1

    ; Yellow -> f (0x46)
    a2 := (now - lastPress[2] > cooldown) ? ColorMatch(c2, yellowTarget, yellowTolerance) : wasActive[2]
    if (a2 && !wasActive[2]) {
        SendBackgroundKey(0x46, "F")
        lastPress[2] := now
        hit := true
    }
    wasActive[2] := a2

    ; Red -> j (0x4A)
    a3 := (now - lastPress[3] > cooldown) ? ColorMatch(c3, redTarget, redTolerance) : wasActive[3]
    if (a3 && !wasActive[3]) {
        SendBackgroundKey(0x4A, "J")
        lastPress[3] := now
        hit := true
    }
    wasActive[3] := a3

    ; Purple -> k (0x4B)
    a4 := (now - lastPress[4] > cooldown) ? ColorMatch(c4, purpleTarget, purpleTolerance) : wasActive[4]
    if (a4 && !wasActive[4]) {
        SendBackgroundKey(0x4B, "K")
        lastPress[4] := now
        hit := true
    }
    wasActive[4] := a4

    ; Update debug window swatches on hit or every 1s
    static lastGuiUpdate := 0
    if (hit || (now - lastGuiUpdate > 1000)) {
        debugGui["Sw1"].Opt("Background" Format("{:06X}", c1))
        debugGui["Sw2"].Opt("Background" Format("{:06X}", c2))
        debugGui["Sw3"].Opt("Background" Format("{:06X}", c3))
        debugGui["Sw4"].Opt("Background" Format("{:06X}", c4))
        lastGuiUpdate := now
    }
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

; Function to click the Play button in the background
ClickPlay() {
    global winW, winH, refW, refH, gameTitle
    hwnd := WinExist(gameTitle)
    if !hwnd
        return

    ; Target coordinates relative to the client area (3840x2160 reference)
    relX := Round(3195 * winW / refW)
    relY := Round(2022 * winH / refH)

    ; Send activation before click
    PostMessage(0x0006, 1, 0, , hwnd)

    ; Use ControlClick with Pos mode for reliability
    ControlClick("x" relX " y" relY, hwnd, , "LEFT", 1, "NA")
}

RemoveToolTip() {
    ToolTip
}

F4::ExitApp
