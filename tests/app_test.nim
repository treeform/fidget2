#[

test a bunch of example apps:
  * compile the app
  * run the app
  * click on the app
  * type into the app
  * take a bunch of screenshots at steps
  * diff screenshots to previous version
]#

import os, osproc, times, encode, strutils
import winim, pixie, bumpy
import winim/inc/windef

proc takeScreenshot*(bounds: bumpy.Rect): Image=
  ## Take a screenshot of bounds on screen.
  let
    x = bounds.x.int
    y = bounds.y.int
    w = bounds.w.int
    h = bounds.h.int
  var image = newImage(w, h)
  var
    hScreen = GetDC(cast[HWND](nil))
    hDC = CreateCompatibleDC(hScreen)
    hBitmap = CreateCompatibleBitmap(hScreen, int32 w, int32 h)
  discard SelectObject(hDC, hBitmap)
  discard BitBlt(hDC, 0, 0, int32 w, int32 h, hScreen, int32 x, int32 y, SRCCOPY)
  # setup bmi structure
  var mybmi: BITMAPINFO
  mybmi.bmiHeader.biSize = int32 sizeof(mybmi)
  mybmi.bmiHeader.biWidth = int32 w
  mybmi.bmiHeader.biHeight = int32 h
  mybmi.bmiHeader.biPlanes = 1
  mybmi.bmiHeader.biBitCount = 32
  mybmi.bmiHeader.biCompression = BI_RGB
  mybmi.bmiHeader.biSizeImage = int32 w * h * 4
  # copy data from bmi structure to the flippy image
  discard CreateDIBSection(hdc, addr mybmi, DIB_RGB_COLORS, cast[ptr pointer](unsafeAddr image.data[0]), 0, 0)
  discard GetDIBits(hdc, hBitmap, 0, int32 h, cast[ptr pointer](unsafeAddr image.data[0]), addr mybmi, DIB_RGB_COLORS)
  # for some reason windows bitmaps are flipped? flip it back
  image.flipVertical()
  # for some reason windows uses BGR, convert it to RGB
  for i in 0 ..< image.height * image.width:
    swap image.data[i].r, image.data[i].b
  # delete data [they are not needed anymore]
  DeleteObject hdc
  DeleteObject hBitmap
  return image

proc run(cmd: string) =
  let code = os.execShellCmd(cmd)
  if code != 0:
    quit("failed")

proc listAllWindows() =
  proc enumWindowCallback(hWnd: HWND, P2: LPARAM): WINBOOL {.stdcall.} =
    if IsWindowVisible(hWnd):
      var text = newString(256)
      var length = SendMessage(hWnd, WM_GETTEXT, 256, cast[LPARAM](text[0].addr)).int
      text.setLen(length)
      echo fromUTF16(text)
    return true
  EnumWindows(enumWindowCallback, 0)

var gFound: bool
var gTitle: string
var gResult: bumpy.Rect
proc getWindowBounds(title: string): (bool, bumpy.Rect) =
  ## Get bounds of a window based on title.
  gTitle = title
  proc enumWindowCallback(hWnd: HWND, P2: LPARAM): WINBOOL {.stdcall.} =
    if IsWindowVisible(hWnd):
      var text = newString(256)
      var length = SendMessage(hWnd, WM_GETTEXT, 256, cast[LPARAM](text[0].addr)).int
      text.setLen(length*2)
      text = fromUTF16(text)
      if text == gTitle:
        var lpRect: windef.RECT
        GetWindowRect(hWnd, lpRect.addr)
        gResult.x = float32(lpRect.top)
        gResult.y = float32(lpRect.left)
        gResult.w = float32(lpRect.right - lpRect.left)
        gResult.h = float32(lpRect.bottom - lpRect.top)
        gFound = true
    return true
  gFound = false
  discard EnumWindows(enumWindowCallback, 0)
  if gFound:
    var bounds = gResult
    bounds.y += 1
    bounds.x += 3
    bounds.w -= 6
    bounds.h -= 4
    return (gFound, bounds)

proc getCursorPos(): Vec2 =
  ## Get current position on screen.
  var p: POINT
  GetCursorPos(cast[LPPOINT](addr p))
  result.x = p.x.float32
  result.y = p.y.float32

proc setCursorPos(pos: Vec2) =
  ## Set current position on screen.
  var x = DWORD(pos.x / 2560.0 * 65535.0)
  var y = DWORD(pos.y / 1440.0 * 65535.0)
  mouse_event(MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE, x, y, 0, 0)

proc leftClick() =
  ## Force a left click.
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)

proc rightClick() =
  ## Force a right click.
  mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0)
  mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)

proc makeDiffHtml() =
  var html = """
  <style>
    body {background-color: gray; font-family: Sans-Serif;}
  </style>

  """
  for f in walkFiles("ss/*.png"):
    let
      f = f.replace("\\", "/")
      fmaster = f.replace("ss/", "ss/masters/")
      fdiff = f.replace("ss/", "ss/diffs/")
      a = readImage(f)
      b = readImage(fmaster)
      (score, c) = diff(a, b)

    html.add "<h2>" & f & "</h2>\n"
    html.add "<img src='" & f & "'>\n"
    html.add "<img src='" & fmaster & "'>\n"
    html.add "<img src='" & fdiff & "'>\n"
    html.add "<p> score: " & $score & "</p>\n"
    c.writeFile(fdiff)

  writeFile("ss.html", html)

proc testCounter() =
  #run r"nim c -d:release examples/the7gui/counter.nim"
  var p = startProcess(r"examples/the7gui/counter.exe")
  var frameNum = 0
  while p.running:
    var (found, bounds) = getWindowBounds("Counter")
    if found:
      var img = takeScreenshot(bounds)
      img.writeFile("ss/" & "Counter" & "." & $frameNum & ".png")
      inc frameNum
      setCursorPos(bounds.xy + vec2(180, 60))
      leftClick()
      echo "ss"
    sleep(100)

    if frameNum > 3:
      setCursorPos(bounds.xy + vec2(bounds.w - 20, 13))
      leftClick()
      sleep(100)
      break

  if p.peekExitCode != 0:
    quit("failed")

testCounter()

makeDiffHtml()
