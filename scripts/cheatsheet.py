import os
import sys
import ctypes
from ctypes import wintypes
import tkinter as tk

WINDOW_TITLE = "Komorebi Hotkeys HUD"

# If already open on screen, send WM_CLOSE to toggle off and exit immediately
user32 = ctypes.windll.user32
existing_hwnd = user32.FindWindowW(None, WINDOW_TITLE)
if existing_hwnd:
    user32.PostMessageW(existing_hwnd, 0x0010, 0, 0)  # WM_CLOSE
    sys.exit(0)

def close_app():
    try:
        root.destroy()
    except Exception:
        pass
    sys.exit(0)

# Colors matching Windows 11 dark minimalism
BG_MAIN = "#1c1c1c"
BG_CARD = "#242424"
BORDER_COLOR = "#333333"
TEXT_PRIMARY = "#f0f0f0"
TEXT_SECONDARY = "#9e9e9e"
TEXT_MUTED = "#6e6e6e"
KEY_BG = "#2b2b2b"
KEY_FG = "#ffffff"
KEY_BORDER = "#3a3a3a"

root = tk.Tk()
root.title(WINDOW_TITLE)
root.protocol("WM_DELETE_WINDOW", close_app)
root.overrideredirect(True)
root.attributes("-topmost", True)
root.attributes("-alpha", 0.98)
root.configure(bg=BORDER_COLOR)

# Outer frame for 1px subtle border
outer_frame = tk.Frame(root, bg=BORDER_COLOR, padx=1, pady=1)
outer_frame.pack(fill="both", expand=True)

main_frame = tk.Frame(outer_frame, bg=BG_MAIN, padx=22, pady=18)
main_frame.pack(fill="both", expand=True)

# Header
header = tk.Frame(main_frame, bg=BG_MAIN)
header.pack(fill="x", pady=(0, 14))

title_label = tk.Label(
    header,
    text="Горячие клавиши",
    font=("Segoe UI", 12, "bold"),
    fg=TEXT_PRIMARY,
    bg=BG_MAIN
)
title_label.pack(side="left")

hint_label = tk.Label(
    header,
    text="Esc или клик — закрыть",
    font=("Segoe UI", 9),
    fg=TEXT_MUTED,
    bg=BG_MAIN
)
hint_label.pack(side="right")

# Divider
divider = tk.Frame(main_frame, bg=BORDER_COLOR, height=1)
divider.pack(fill="x", pady=(0, 16))

# Columns definition (Zero emojis, clean minimalist categories)
columns_data = [
    ("Окна и фокус", [
        ("Alt + H / J / K / L", "Фокус влево / вниз / вверх / вправо"),
        ("Alt + Стрелки", "Фокус стрелками"),
        ("Alt + Shift + H/J/K/L", "Переместить окно в сетке"),
        ("Alt + Shift + Enter", "Сделать главным (Promote)"),
        ("Alt + Shift + Q", "Закрыть активное окно"),
        ("Alt + Shift + M", "Свернуть окно"),
        ("Alt + Shift + [ / ]", "Циклический перебор окон"),
    ]),
    ("Сетка и мониторы", [
        ("Alt + F", "Окно: свободное / в сетке (Float)"),
        ("Alt + Shift + F", "На весь экран (Monocle)"),
        ("Alt + Q", "Пересчитать сетку (Retile)"),
        ("Alt + P", "Пауза тайлинга (свободные окна)"),
        ("Alt + . (Ю) / , (Б)", "Фокус след. / пред. монитор"),
        ("Alt + Shift + . / ,", "Окно на соседний монитор"),
        ("Alt + + / -", "Ширина сплита"),
        ("Alt + Shift + + / -", "Высота сплита"),
        ("Alt + U", "Прозрачность неактивных окон"),
        ("Alt + Shift + U", "Прозрачность активного окна"),
    ]),
    ("Профили и запуск", [
        ("Alt + 1 .. 7", "Перейти на профиль (DEV, WEB...)"),
        ("Alt + Shift + 1 .. 7", "Перенести окно на профиль"),
        ("Alt + Enter / Alt + T", "Терминал (pwsh)"),
        ("Alt + E", "Проводник OneCommander"),
        ("Win + E", "Проводник Windows"),
        ("Alt + B", "Скрыть / показать панель задач"),
        ("Alt + O", "Перезагрузить хоткеи (whkd)"),
        ("Alt + Shift + O", "Перезагрузить Komorebi"),
    ]),
]

content = tk.Frame(main_frame, bg=BG_MAIN)
content.pack(fill="both", expand=True)

for col_idx, (cat_name, items) in enumerate(columns_data):
    col_card = tk.Frame(
        content,
        bg=BG_CARD,
        padx=14,
        pady=12,
        highlightbackground=BORDER_COLOR,
        highlightthickness=1
    )
    col_card.grid(row=0, column=col_idx, padx=6, sticky="nsew")
    content.columnconfigure(col_idx, weight=1)

    cat_label = tk.Label(
        col_card,
        text=cat_name,
        font=("Segoe UI", 10, "bold"),
        fg=TEXT_PRIMARY,
        bg=BG_CARD
    )
    cat_label.pack(anchor="w", pady=(0, 10))

    for key_combo, desc in items:
        row = tk.Frame(col_card, bg=BG_CARD)
        row.pack(fill="x", pady=2)

        key_box = tk.Label(
            row,
            text=key_combo,
            font=("Consolas", 8, "bold"),
            fg=KEY_FG,
            bg=KEY_BG,
            padx=5,
            pady=1,
            highlightbackground=KEY_BORDER,
            highlightthickness=1
        )
        key_box.pack(side="left")

        desc_label = tk.Label(
            row,
            text=desc,
            font=("Segoe UI", 8),
            fg=TEXT_SECONDARY,
            bg=BG_CARD,
            anchor="w"
        )
        desc_label.pack(side="left", padx=(8, 0), fill="x", expand=True)

# Calculate screen placement based on cursor monitor
root.update_idletasks()
w = root.winfo_reqwidth()
h = root.winfo_reqheight()

class RECT(ctypes.Structure):
    _fields_ = [('left', ctypes.c_long), ('top', ctypes.c_long), ('right', ctypes.c_long), ('bottom', ctypes.c_long)]

class MONITORINFO(ctypes.Structure):
    _fields_ = [('cbSize', ctypes.c_ulong), ('rcMonitor', RECT), ('rcWork', RECT), ('dwFlags', ctypes.c_ulong)]

try:
    pt = wintypes.POINT()
    user32.GetCursorPos(ctypes.byref(pt))
    h_mon = user32.MonitorFromPoint(pt, 1)
    mi = MONITORINFO()
    mi.cbSize = ctypes.sizeof(MONITORINFO)
    user32.GetMonitorInfoW(h_mon, ctypes.byref(mi))
    
    mon_w = mi.rcWork.right - mi.rcWork.left
    mon_h = mi.rcWork.bottom - mi.rcWork.top
    x = mi.rcWork.left + (mon_w - w) // 2
    y = mi.rcWork.top + (mon_h - h) // 2
except Exception:
    sw = root.winfo_screenwidth()
    sh = root.winfo_screenheight()
    x = (sw - w) // 2
    y = (sh - h) // 2

root.geometry(f"{w}x{h}+{x}+{y}")

root.deiconify()
root.lift()
root.focus_force()

try:
    hwnd = user32.GetParent(root.winfo_id()) or root.winfo_id()
    user32.SetForegroundWindow(hwnd)
except Exception:
    pass

# Recursive click binding to all widgets
def bind_click_to_all(widget):
    widget.bind("<Button-1>", lambda e: close_app())
    for child in widget.winfo_children():
        bind_click_to_all(child)

bind_click_to_all(root)
root.bind_all("<Escape>", lambda e: close_app())

# Hardware Escape polling check
def poll_escape_key():
    try:
        if user32.GetAsyncKeyState(0x1B) & 0x8000:
            close_app()
            return
        root.after(25, poll_escape_key)
    except Exception:
        pass

root.after(100, poll_escape_key)

root.mainloop()
