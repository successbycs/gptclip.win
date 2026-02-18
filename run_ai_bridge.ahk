#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

; -------------------------
; Ownership / Attribution
; -------------------------
; Project: AI-Bridge
; Author: Chris
; Copyright (c) 2026 Chris
; License: MIT (optional, include LICENSE.txt + NOTICE.txt in your zip)
; -------------------------

; AI-Bridge
; Copy text -> Ctrl+Alt+N -> create new Notepad++ scratch file -> paste -> restore clipboard
;
; Hotkeys:
;   Ctrl + Alt + N  Run
;   Ctrl + Alt + L  Open log folder (%LOCALAPPDATA%\AI-bridge\logs)
;   Ctrl + Alt + R  Reload script
;   Ctrl + Alt + T  Test popup

; -------------------------
; CONFIG
; -------------------------
global AI_BRIDGE_BUILD := "AI-Bridge-v1"
global AI_BRIDGE_OWNER := "Chris"

global AI_BRIDGE_PROJECT_DIR := A_ScriptDir "\scratch"
global AI_BRIDGE_APPDATA_DIRNAME := "AI-bridge"

global AI_BRIDGE_PURGE_ENABLED := true
global AI_BRIDGE_SCRATCH_RETENTION_DAYS := 30

global AI_BRIDGE_RUNNING := false

; Scintilla messages
global SCI_SELECTALL := 2013
global WM_PASTE := 0x302

; Purge old scratch files on startup (best effort)
if (AI_BRIDGE_PURGE_ENABLED) {
    try PurgeScratch()
}

^!n::AI_Bridge_Run()
^!l::OpenLogFolder()
^!r::Reload()
^!t::MsgBox("AI-Bridge is running.`n`nCopy a ChatGPT code block and press Ctrl+Alt+N.")

try TrayTip("AI-Bridge running", "Ctrl+Alt+N to paste. Ctrl+Alt+T to test.", 2)

AI_Bridge_Run() {
    global AI_BRIDGE_RUNNING, AI_BRIDGE_PURGE_ENABLED

    if (AI_BRIDGE_RUNNING) {
        Tooltip("AI-Bridge already running", 10, 10)
        SetTimer(() => Tooltip(), -800)
        return
    }
    AI_BRIDGE_RUNNING := true

    VERSION := "0.1"
    MAX_RETRIES := 3

    runId := FormatTime(A_Now, "yyyyMMdd-HHmmss") "_" A_TickCount
    status := "success"
    errorCode := ""

    nppRetries := 0
    pasteRetries := 0

    tAll := A_TickCount
    tClipboard := 0
    tNpp := 0
    tNewFile := 0
    tPaste := 0
    tRestore := 0

    clipSaved := ClipboardAll()
    hwnd := 0
    logPath := ""

    try SoundBeep(900, 60)

    try {
        ; ClipboardReady
        t0 := A_TickCount
        clipText := GetClipboardTextStrict()
        tClipboard := A_TickCount - t0

        ; NppReady
        t0 := A_TickCount
        ok := false
        lastErr := ""
        while (nppRetries < MAX_RETRIES) {
            res := EnsureNppReady()
            ok := res[1], lastErr := res[2], hwnd := res[3]
            if (ok)
                break
            nppRetries += 1
            Sleep(200)
        }
        tNpp := A_TickCount - t0

        if (!ok) {
            status := "error"
            errorCode := (lastErr != "" ? lastErr : "NPP_TIMEOUT")
            throw Error(errorCode)
        }

        ; Open new scratch file
        t0 := A_TickCount
        res := OpenNewScratchFileInNpp(hwnd)
        ok := res[1], lastErr := res[2], hwnd := res[3]
        tNewFile := A_TickCount - t0

        if (!ok) {
            status := "error"
            errorCode := (lastErr != "" ? lastErr : "FILE_OPEN_FAIL")
            throw Error(errorCode)
        }

        ; PasteDone
        t0 := A_TickCount
        ok := false
        lastErr := ""
        while (pasteRetries < MAX_RETRIES) {
            res := PasteIntoNpp(hwnd, clipText)
            ok := res[1], lastErr := res[2]
            if (ok)
                break
            pasteRetries += 1
            Sleep(200)
        }
        tPaste := A_TickCount - t0

        if (!ok) {
            status := "error"
            errorCode := (lastErr != "" ? lastErr : "PASTE_FAIL")
            throw Error(errorCode)
        }

        ; Purge old scratch files after success (best effort)
        if (AI_BRIDGE_PURGE_ENABLED) {
            try PurgeScratch()
        }
    }
    catch as e {
        status := "error"
        if (errorCode = "")
            errorCode := (e.Message != "" ? e.Message : "UNKNOWN")
    }

    ; RestoreClipboardDone (always)
    t0 := A_TickCount
    RestoreClipboard(clipSaved)
    tRestore := A_TickCount - t0

    totalMs := A_TickCount - tAll

    ; Logging (best effort)
    try {
        logPath := LogRun(VERSION, runId, status, errorCode, nppRetries, pasteRetries, tClipboard, tNpp, tNewFile, tPaste, tRestore, totalMs)
    } catch {
        logPath := ""
    }

    if (status = "success") {
        Tooltip("AI-Bridge OK`nLog: " (logPath != "" ? logPath : "FAILED"), 10, 10)
        SetTimer(() => Tooltip(), -1500)
    } else {
        msg := "AI-Bridge failed.`n`nError: " errorCode
        if (errorCode = "CLIP_EMPTY")
            msg .= "`n`nClipboard has no text. Copy text (not an image/file)."
        if (errorCode = "NPP_NOT_FOUND")
            msg .= "`n`nNotepad++ not found in standard install paths."
        msg .= "`n`nLog: " (logPath != "" ? logPath : "FAILED")
        MsgBox(msg)
    }

    AI_BRIDGE_RUNNING := false
}

GetClipboardTextStrict() {
    if (Trim(A_Clipboard) = "") {
        try ClipWait(1, 1)
    }
    txt := A_Clipboard
    if (Trim(txt) = "")
        throw Error("CLIP_EMPTY")
    return txt
}

ActivateWindow(hwnd) {
    if (!hwnd)
        return false
    WinActivate("ahk_id " hwnd)
    return WinWaitActive("ahk_id " hwnd, , 2)
}

PickNppWindow() {
    list := WinGetList("ahk_exe notepad++.exe")
    if (list.Length = 0)
        return 0
    active := WinActive("ahk_exe notepad++.exe")
    if (active)
        return active
    return list[1]
}

GetNppPath() {
    npp1 := A_ProgramFiles "\Notepad++\notepad++.exe"
    if (FileExist(npp1))
        return npp1
    npp2 := A_ProgramFiles " (x86)\Notepad++\notepad++.exe"
    if (FileExist(npp2))
        return npp2
    return ""
}

EnsureNppReady() {
    hwnd := PickNppWindow()
    if (hwnd) {
        if (ActivateWindow(hwnd))
            return [true, "", hwnd]
        return [false, "NPP_ACTIVATE_FAIL", hwnd]
    }

    npp := GetNppPath()
    if (npp = "")
        return [false, "NPP_NOT_FOUND", 0]

    Run('"' npp '" -nosession')

    if (!WinWait("ahk_exe notepad++.exe", , 10))
        return [false, "NPP_TIMEOUT", 0]

    hwnd := PickNppWindow()
    if (!hwnd)
        return [false, "NPP_TIMEOUT", 0]

    if (ActivateWindow(hwnd))
        return [true, "", hwnd]

    return [false, "NPP_ACTIVATE_FAIL", hwnd]
}

OpenNewScratchFileInNpp(hwnd) {
    global AI_BRIDGE_PROJECT_DIR

    try {
        if (!DirExist(AI_BRIDGE_PROJECT_DIR))
            DirCreate(AI_BRIDGE_PROJECT_DIR)
    } catch {
        return [false, "PROJECT_DIR_FAIL", hwnd]
    }

    ts := FormatTime(A_Now, "yyyyMMdd-HHmmss")
    filePath := AI_BRIDGE_PROJECT_DIR "\chatgpt_" ts "_" A_TickCount ".txt"

    try {
        FileAppend("", filePath, "UTF-8")
    } catch {
        return [false, "FILE_CREATE_FAIL", hwnd]
    }

    npp := GetNppPath()
    if (npp = "")
        return [false, "NPP_NOT_FOUND", hwnd]

    try {
        Run('"' npp '" "' filePath '"')
    } catch {
        return [false, "FILE_OPEN_FAIL", hwnd]
    }

    Sleep(250)

    newHwnd := PickNppWindow()
    if (!newHwnd)
        newHwnd := hwnd

    if (!ActivateWindow(newHwnd))
        return [false, "NPP_ACTIVATE_FAIL", newHwnd]

    return [true, "", newHwnd]
}

; Key change: NO Ctrl+A keystroke.
; We use Scintilla SCI_SELECTALL (2013) to select all, then WM_PASTE.
PasteIntoNpp(hwnd, clipText) {
    global SCI_SELECTALL, WM_PASTE

    if (!hwnd)
        return [false, "NPP_TIMEOUT"]

    if (!ActivateWindow(hwnd))
        return [false, "NPP_ACTIVATE_FAIL"]

    ctrl := ""
    tries := 0
    while (tries < 15) {
        ctrl := GetScintillaCtrl(hwnd)
        if (ctrl != "")
            break
        tries += 1
        Sleep(80)
    }
    if (ctrl = "")
        return [false, "SCINTILLA_NOT_FOUND"]

    ; Put desired text into clipboard (we restore later)
    A_Clipboard := clipText
    if (!ClipWait(1, 1))
        return [false, "CLIP_TIMEOUT"]
    Sleep(30)

    try {
        ControlFocus(ctrl, "ahk_id " hwnd)
        Sleep(30)

        ; Select all via Scintilla message (not keystrokes)
        SendMessage(SCI_SELECTALL, 0, 0, ctrl, "ahk_id " hwnd)
        Sleep(20)

        ; Paste via WM_PASTE
        SendMessage(WM_PASTE, 0, 0, ctrl, "ahk_id " hwnd)
        return [true, ""]
    } catch {
        return [false, "PASTE_FAIL"]
    }
}

GetScintillaCtrl(hwnd) {
    winTitle := "ahk_id " hwnd
    try {
        h := ControlGetHwnd("Scintilla1", winTitle)
        if (h)
            return "Scintilla1"
    } catch {
    }
    try {
        h := ControlGetHwnd("Scintilla2", winTitle)
        if (h)
            return "Scintilla2"
    } catch {
    }
    return ""
}

RestoreClipboard(clipSaved) {
    try A_Clipboard := clipSaved
}

PurgeScratch() {
    global AI_BRIDGE_PROJECT_DIR, AI_BRIDGE_SCRATCH_RETENTION_DAYS

    if (!DirExist(AI_BRIDGE_PROJECT_DIR))
        return

    cutoff := DateAdd(A_Now, -AI_BRIDGE_SCRATCH_RETENTION_DAYS, "Days")

    Loop Files, AI_BRIDGE_PROJECT_DIR "\chatgpt_*.txt", "F" {
        try {
            fileTime := FileGetTime(A_LoopFileFullPath, "M")
            if (fileTime != "" && fileTime < cutoff)
                FileDelete(A_LoopFileFullPath)
        } catch {
        }
    }
}

ResolveLogFilePath() {
    global AI_BRIDGE_APPDATA_DIRNAME

    localAppData := EnvGet("LOCALAPPDATA")
    if (localAppData = "")
        localAppData := A_AppData

    return localAppData "\" AI_BRIDGE_APPDATA_DIRNAME "\logs\runs.tsv"
}

LogRun(version, runId, status, errorCode, nppRetries, pasteRetries, tClipboard, tNpp, tNewFile, tPaste, tRestore, totalMs) {
    global AI_BRIDGE_BUILD, AI_BRIDGE_OWNER

    logFile := ResolveLogFilePath()
    SplitPath(logFile, , &logDir)

    if (!DirExist(logDir))
        DirCreate(logDir)

    ts := FormatTime(A_Now, "yyyy-MM-ddTHH:mm:ss")
    line := ts "`t" AI_BRIDGE_BUILD "`t" AI_BRIDGE_OWNER "`t" version "`t" runId "`t" status "`t" errorCode "`t"
        . nppRetries "`t" pasteRetries "`t"
        . tClipboard "`t" tNpp "`t" tNewFile "`t" tPaste "`t" tRestore "`t" totalMs "`n"

    FileAppend(line, logFile, "UTF-8")
    return logFile
}

OpenLogFolder() {
    logFile := ResolveLogFilePath()
    SplitPath(logFile, , &dir)
    Run(dir)
}
