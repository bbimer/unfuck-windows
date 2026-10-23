using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

internal static class Program
{
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool EnableWindow(IntPtr hWnd, bool bEnable);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetThreadDesktop(IntPtr hDesktop);

    private const int SW_HIDE = 0;
    private const int SW_SHOW = 5;
    private const uint GENERIC_ALL = 0x10000000;

    private static string LogPath = @"C:\Users\root\.config\toggle_taskbar.log";

    private static void Log(string msg)
    {
        try
        {
            File.AppendAllText(LogPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " - " + msg + Environment.NewLine);
        }
        catch {}
    }

    private static void Main()
    {
        var thread = new System.Threading.Thread(() =>
        {
            try
            {
                IntPtr hDesk = OpenDesktop("default", 0, false, GENERIC_ALL);
                if (hDesk != IntPtr.Zero)
                {
                    SetThreadDesktop(hDesk);
                }
            }
            catch {}

            RunToggle();
        });

        thread.SetApartmentState(System.Threading.ApartmentState.MTA);
        thread.Start();
        thread.Join();
    }

    private static void RunToggle()
    {
        var taskbars = new List<IntPtr>();
        var classBuf = new StringBuilder(256);

        EnumWindows((hWnd, lParam) =>
        {
            classBuf.Clear();
            GetClassName(hWnd, classBuf, classBuf.Capacity);
            string cls = classBuf.ToString();

            if (cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd")
            {
                uint pid = 0;
                GetWindowThreadProcessId(hWnd, out pid);
                try
                {
                    var proc = Process.GetProcessById((int)pid);
                    if (string.Equals(proc.ProcessName, "explorer", StringComparison.OrdinalIgnoreCase))
                    {
                        taskbars.Add(hWnd);
                    }
                }
                catch {}
            }
            return true;
        }, IntPtr.Zero);

        if (taskbars.Count == 0)
        {
            Log("No explorer taskbar windows found");
            return;
        }

        bool anyVisible = false;
        foreach (var hwnd in taskbars)
        {
            if (IsWindowVisible(hwnd))
            {
                anyVisible = true;
                break;
            }
        }

        int cmd = anyVisible ? SW_HIDE : SW_SHOW;
        bool enable = !anyVisible;

        Log(string.Format("Found {0} taskbar(s). Action: {1}", taskbars.Count, anyVisible ? "HIDE" : "SHOW"));

        foreach (var hwnd in taskbars)
        {
            ShowWindow(hwnd, cmd);
            EnableWindow(hwnd, enable);
        }
    }
}
