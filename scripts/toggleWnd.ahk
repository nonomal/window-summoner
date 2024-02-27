﻿#Include utils.ahk
#Include ../app.ahk

; id - onExitHandlers
wndHandlers := Map()

; 活跃的已唤起窗口
activatedWnd := false

; Toggle between hidden and shown
toggleWnd(id, entry := unset) {
  static pending := false
  ; Prevent concurrent actions only if singleActiveWindow is on
  if (config["misc"]["singleActiveWindow"] && pending) {
    return id
  }
  pending := true
  global wndHandlers
  global activatedWnd
  global config

  ; Id valid
  if (id && WinExist(id)) {
    if (!config["misc"]["minimizeInstead"]) {
      ; Hide / Show
      isVisible := WinGetStyle(id) & 0x10000000
      if (isVisible && WinActive(id)) {
        _hide(id)
      } else {
        _show(id)
      }
    } else {
      ; Minimize / Restore
      if (WinActive(id)) {
        _minimize(id)
      } else {
        _restore(id)
      }
    }
  }
  ; Id invalid & entry provided
  else if (IsSet(entry)) {
    if (config["misc"]["singleActiveWindow"] && activatedWnd) {
      if (!config["misc"]["minimizeInstead"])
        _hide(activatedWnd, false)
      else
        _minimize(activatedWnd)
    }
    _run()
  }

  _run() {
    Run(entry["run"])
    ; Retrieve id
    if (entry["wnd_title"] !== "") {
      id := WinWait(entry["wnd_title"])
    } else {
      currentWnd := WinGetLatest()
      while (WinGetLatest() == currentWnd) {
        Sleep(35)
      }
      id := WinGetLatest()
    }
    ; Update activatedWnd
    if (id) {
      activatedWnd := id
    }
  }

  _hide(id, restoreLastActive := true) {
    try {
      ; WinMinimize(id)
      WinHide(id)
      activatedWnd := false
    }
    ; Restore focus
    if (restoreLastActive) {
      try {
        DetectHiddenWindows(false)
        wndList := WinGetList()
        topWnd := wndList[wndList.FindIndex((wnd) => WinGetMinMax(wnd) > -1) + 1]
        WinActivate(topWnd)
        DetectHiddenWindows(true)
      }
    }
    ; Handle exit, try to reuse handler
    if (!wndHandlers.Has(String(id))) {
      ; id is remembered in closure
      exitHandler := (e, c) {
        try {
          isVisible := WinGetStyle(id) & 0x10000000
          if (!isVisible) {
            WinShow(id)
          }
        }
      }
      ; Keep a record of bound exitHandlers
      wndHandlers.Set(String(id), exitHandler)
      OnExit(exitHandler, 1)
      OnError(exitHandler, 1)
    }
  }

  _show(id) {
    ; Hide other active windows
    if (config["misc"]["singleActiveWindow"] && activatedWnd && activatedWnd !== id) {
      _hide(activatedWnd, false)
    }
    try {
      WinShow(id)
      WinActivate(id)
      activatedWnd := id
    }
  }
  _minimize(id) {
    try {
      WinMinimize(id)
      activatedWnd := false
    }
  }
  _restore(id) {
    try {
      if (config["misc"]["singleActiveWindow"]) {
        if (activatedWnd && activatedWnd !== id) {
          _minimize(activatedWnd)
        }
      }
    }
    try {
      if (WinGetMinMax(id) == -1)
        WinRestore(id)
      ; WinActivate(id)
      activatedWnd := id
    }
  }
  pending := false
  return id
}
clearWndHandlers() {
  global wndHandlers
  global activatedWnd
  activatedWnd := false
  for id, handler in wndHandlers {
    try {
      OnExit(handler, 0)
      OnError(handler, 0)
      handler("", "")
    }
  }
  wndHandlers := Map()
}