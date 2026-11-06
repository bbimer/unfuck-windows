"""Raycast / Windows 11 Fluent style single-line HUD status bar.
Centered horizontally, placed slightly below screen center (62% Y).
Features:
- Native Windows 11 DWM rounded corners (DWMWA_WINDOW_CORNER_PREFERENCE)
- Native 1px subtle dark border (DWMWA_BORDER_COLOR)
- 60 FPS animated arc spinner for processing phases
- Segoe UI Semibold / Regular calm typography (#e0e0e0)
- Interactive two-phase lifecycle via stdin pipe (PROGRESS -> DONE/ERROR -> Fade-out)
- Standalone single-shot mode with smooth 150ms fade-out
- Non-focus-stealing (WS_EX_NOACTIVATE)
"""

from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import os
import sys
import threading
import time
import tkinter as tk
from typing import Optional

# Win32 / DWM Constants
GWL_EXSTYLE = -20
WS_EX_NOACTIVATE = 0x08000000
WS_EX_TOPMOST = 0x00000008

DWMWA_WINDOW_CORNER_PREFERENCE = 33
DWMWCP_ROUND = 2
DWMWCP_ROUNDSMALL = 3
DWMWA_BORDER_COLOR = 34

user32 = ctypes.windll.user32
dwmapi = ctypes.windll.dwmapi


class RECT(ctypes.Structure):
    _fields_ = [
        ("left", ctypes.c_long),
        ("top", ctypes.c_long),
        ("right", ctypes.c_long),
        ("bottom", ctypes.c_long),
    ]


class MONITORINFO(ctypes.Structure):
    _fields_ = [
        ("cbSize", ctypes.c_ulong),
        ("rcMonitor", RECT),
        ("rcWork", RECT),
        ("dwFlags", ctypes.c_ulong),
    ]


def get_active_monitor_work_area() -> tuple[int, int, int, int]:
    """Returns (x, y, width, height) of monitor under mouse cursor."""
    try:
        pt = wintypes.POINT()
        user32.GetCursorPos(ctypes.byref(pt))
        h_mon = user32.MonitorFromPoint(pt, 1)  # MONITOR_DEFAULTTOPRIMARY
        mi = MONITORINFO()
        mi.cbSize = ctypes.sizeof(MONITORINFO)
        if user32.GetMonitorInfoW(h_mon, ctypes.byref(mi)):
            mx = mi.rcWork.left
            my = mi.rcWork.top
            mw = mi.rcWork.right - mi.rcWork.left
            mh = mi.rcWork.bottom - mi.rcWork.top
            return mx, my, mw, mh
    except Exception:
        pass
    return 0, 0, 1920, 1080


class HudStatusBar:
    def __init__(self, interactive: bool = False, initial_type: str = "progress", initial_text: str = ""):
        self.interactive = interactive
        self.state_type = initial_type
        self.text = initial_text
        self.spinning = False
        self.angle = 0
        self.fade_steps = 10
        self.fade_interval_ms = 15
        self.closed = False

        self.root = tk.Tk()
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 0.96)
        self.root.config(bg="#141414")

        # Main inner container
        self.height = 36
        self.min_width = 240
        self.padding_x = 16

        self.frame = tk.Frame(self.root, bg="#141414", height=self.height)
        self.frame.pack(fill="both", expand=True)

        # Indicator (16x16 canvas for spinner or text for icons)
        self.indicator_size = 16
        self.canvas = tk.Canvas(
            self.frame,
            width=self.indicator_size,
            height=self.indicator_size,
            bg="#141414",
            highlightthickness=0,
        )
        self.canvas.pack(side="left", padx=(self.padding_x, 10), pady=(self.height - self.indicator_size) // 2)

        # Label with Calm Semibold typography
        self.label = tk.Label(
            self.frame,
            text=self.text,
            font=("Segoe UI Semibold", 10),
            fg="#e0e0e0",
            bg="#141414",
        )
        self.label.pack(side="left", padx=(0, self.padding_x), pady=0)

        # Native Windows 11 DWM Styling
        self.root.update_idletasks()
        self.setup_dwm_attributes()

        # Update initial geometry
        self.recalculate_geometry()

        # Start animation or schedule exit
        if self.state_type == "progress":
            self.start_spinner()
        else:
            self.draw_static_icon(self.state_type)
            if not self.interactive:
                self.schedule_dismiss(850)

        # Click to dismiss
        self.frame.bind("<Button-1>", lambda e: self.fade_out())
        self.label.bind("<Button-1>", lambda e: self.fade_out())
        self.canvas.bind("<Button-1>", lambda e: self.fade_out())

        # Start stdin listener thread if interactive
        if self.interactive:
            self.listener_thread = threading.Thread(target=self._stdin_worker, daemon=True)
            self.listener_thread.start()
            # Safety timeout: 20 seconds auto-dismiss
            self.root.after(20000, self.fade_out)

    def setup_dwm_attributes(self) -> None:
        """Applies Windows 11 native hardware rounded corners & subtle border."""
        try:
            hwnd_child = self.root.winfo_id()
            hwnd = user32.GetParent(hwnd_child) or hwnd_child

            # 1. Non-activating style
            ex_style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            user32.SetWindowLongW(hwnd, GWL_EXSTYLE, ex_style | WS_EX_NOACTIVATE | WS_EX_TOPMOST)

            # 2. DWM Rounded Corners (ROUNDSMALL = 3, gives sleek 8-10px corner)
            val_corner = ctypes.c_int(DWMWCP_ROUNDSMALL)
            dwmapi.DwmSetWindowAttribute(
                hwnd,
                DWMWA_WINDOW_CORNER_PREFERENCE,
                ctypes.byref(val_corner),
                ctypes.sizeof(val_corner),
            )

            # 3. DWM 1px Border (#282828 -> COLORREF 0x00282828)
            val_border = ctypes.c_int(0x00282828)
            dwmapi.DwmSetWindowAttribute(
                hwnd,
                DWMWA_BORDER_COLOR,
                ctypes.byref(val_border),
                ctypes.sizeof(val_border),
            )
        except Exception:
            pass

    def recalculate_geometry(self) -> None:
        """Calculates dynamic width based on text length and centers horizontally at 62% screen height."""
        self.root.update_idletasks()
        req_w = self.label.winfo_reqwidth() + self.indicator_size + (self.padding_x * 2) + 12
        w = max(self.min_width, req_w)
        h = self.height

        mx, my, mw, mh = get_active_monitor_work_area()
        pos_x = mx + (mw - w) // 2
        # Position slightly below vertical center (62% of monitor work area)
        pos_y = my + int(mh * 0.62) - (h // 2)

        self.root.geometry(f"{w}x{h}+{pos_x}+{pos_y}")

    def start_spinner(self) -> None:
        """Starts 60 FPS spinning arc animation."""
        self.spinning = True
        self.canvas.delete("all")
        self.arc = self.canvas.create_arc(
            2, 2, self.indicator_size - 2, self.indicator_size - 2,
            start=0, extent=260,
            outline="#38bdf8", width=2, style="arc"
        )
        self._animate_spin()

    def _animate_spin(self) -> None:
        if self.spinning and not self.closed:
            self.angle = (self.angle + 12) % 360
            self.canvas.itemconfigure(self.arc, start=self.angle)
            self.root.after(16, self._animate_spin)

    def draw_static_icon(self, icon_type: str) -> None:
        """Stops spinner and displays clean symbol."""
        self.spinning = False
        self.canvas.delete("all")

        presets = {
            "done": ("✓", "#10b981", 11),
            "success": ("✓", "#10b981", 11),
            "error": ("✕", "#ef4444", 10),
            "path": ("↗", "#38bdf8", 11),
            "audit": ("✦", "#f59e0b", 11),
            "copy": ("✓", "#10b981", 11),
        }
        sym, color, size = presets.get(icon_type.lower(), ("✓", "#10b981", 11))
        self.canvas.create_text(
            self.indicator_size // 2,
            self.indicator_size // 2,
            text=sym,
            fill=color,
            font=("Segoe UI", size, "bold"),
        )

    def set_state(self, state: str, text: str) -> None:
        """Thread-safe UI update."""
        def _update():
            self.state_type = state.lower()
            self.label.config(text=text)
            self.recalculate_geometry()

            if self.state_type == "progress":
                if not self.spinning:
                    self.start_spinner()
            else:
                self.draw_static_icon(self.state_type)
                # Auto dismiss after done / error
                pause_ms = 850 if self.state_type in ("done", "success", "path", "copy") else 1600
                self.schedule_dismiss(pause_ms)

        self.root.after(0, _update)

    def schedule_dismiss(self, delay_ms: int = 850) -> None:
        self.root.after(delay_ms, self.fade_out)

    def fade_out(self, current_step: int = 0) -> None:
        """Smooth 150ms fade-out transition."""
        if self.closed:
            return
        if current_step < self.fade_steps:
            new_alpha = max(0.0, 0.96 * (1.0 - (current_step + 1) / self.fade_steps))
            self.root.attributes("-alpha", new_alpha)
            self.root.after(self.fade_interval_ms, lambda: self.fade_out(current_step + 1))
        else:
            self.closed = True
            try:
                self.root.destroy()
            except Exception:
                pass
            sys.exit(0)

    def _stdin_worker(self) -> None:
        """Listens for IPC commands on low-level stdin descriptor (unbuffered os.read)."""
        buffer = ""
        try:
            while not self.closed:
                chunk = os.read(0, 1024)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="replace")
                while "\n" in buffer:
                    line, buffer = buffer.split("\n", 1)
                    line = line.strip()
                    if not line:
                        continue
                    if line.startswith("PROGRESS:"):
                        msg = line.split(":", 1)[1]
                        self.set_state("progress", msg)
                    elif line.startswith("DONE:"):
                        msg = line.split(":", 1)[1]
                        self.set_state("done", msg)
                    elif line.startswith("ERROR:"):
                        msg = line.split(":", 1)[1]
                        self.set_state("error", msg)
                    elif line.startswith("PATH:"):
                        msg = line.split(":", 1)[1]
                        self.set_state("path", msg)
                    elif line == "CLOSE":
                        self.root.after(0, self.fade_out)
                        return
        except Exception:
            pass

    def run(self) -> None:
        self.root.mainloop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Raycast style single-line HUD status bar")
    parser.add_argument("--interactive", action="store_true", help="Run in interactive stdin stream mode")
    parser.add_argument("--type", default="success", help="progress | done | success | error | path | audit")
    parser.add_argument("--message", default="", help="Status text")
    parser.add_argument("--duration", type=int, default=850, help="Hold duration before fade-out (ms)")

    # Backwards compatibility flags
    parser.add_argument("--title", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--label", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--details", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--badge", default=None, help=argparse.SUPPRESS)

    args, _ = parser.parse_known_args()

    init_text = args.message
    init_type = args.type

    if not init_text and args.interactive:
        init_text = "Обработка видео..."
        init_type = "progress"
    elif not init_text:
        init_text = "Готово"

    bar = HudStatusBar(
        interactive=args.interactive,
        initial_type=init_type,
        initial_text=init_text,
    )
    bar.run()
