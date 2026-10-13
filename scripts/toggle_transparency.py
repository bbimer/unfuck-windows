import ctypes
from ctypes import wintypes
import sys

user32 = ctypes.windll.user32

GWL_EXSTYLE = -20
WS_EX_LAYERED = 0x00080000
LWA_ALPHA = 0x02
TARGET_ALPHA = 215  # ~84% opacity

hwnd = user32.GetForegroundWindow()
if not hwnd:
    sys.exit(0)

ex_style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)

cr_key = wintypes.COLORREF()
alpha = wintypes.BYTE()
flags = wintypes.DWORD()

is_layered = bool(ex_style & WS_EX_LAYERED)
current_alpha = 255

if is_layered:
    if user32.GetLayeredWindowAttributes(hwnd, ctypes.byref(cr_key), ctypes.byref(alpha), ctypes.byref(flags)):
        if flags.value & LWA_ALPHA:
            current_alpha = alpha.value

if is_layered and current_alpha < 250:
    # Restore full opacity
    user32.SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA)
    user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style & ~WS_EX_LAYERED)
else:
    # Make transparent
    user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style | WS_EX_LAYERED)
    user32.SetLayeredWindowAttributes(hwnd, 0, TARGET_ALPHA, LWA_ALPHA)

user32.RedrawWindow(hwnd, None, None, 0x0001 | 0x0004 | 0x0100) # RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW

