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

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EnumDesktopWindows(IntPtr hDesktop, EnumWindowsProc lpfn, IntPtr lParam);

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

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern IntPtr OpenDesktop(string lpszDesktop, uint dwFlags, bool fInherit, uint dwDesiredAccess);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool CloseDesktop(IntPtr hDesktop);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, uint processId);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern bool QueryFullProcessImageName(IntPtr hProcess, uint dwFlags, StringBuilder lpExeName, ref uint lpdwSize);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CloseHandle(IntPtr hObject);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetThreadDesktop(IntPtr hDesktop);

    private const int SW_HIDE = 0;
    private const int SW_SHOW = 5;
    private const uint DESKTOP_ACCESS = 0x01FF;
    private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

    private static string LogPath = @"C:\Users\root\.config\toggle_taskbar.log";

    private static void Log(string msg)
    {
        try
        {
            File.AppendAllText(LogPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + " - " + msg + Environment.NewLine);
        }
        catch {}
    }

    private static bool IsExplorerProcess(uint pid, HashSet<uint> cachedExplorerPids)
    {
        if (pid == 0) return false;
        if (cachedExplorerPids != null && cachedExplorerPids.Contains(pid))
        {
            return true;
        }

        // Strategy: QueryFullProcessImageName with limited information
        IntPtr hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (hProc != IntPtr.Zero)
        {
            try
            {
                var sb = new StringBuilder(1024);
                uint size = (uint)sb.Capacity;
                if (QueryFullProcessImageName(hProc, 0, sb, ref size))
                {
                    string path = sb.ToString();
                    string fileName = Path.GetFileName(path);
                    if (string.Equals(fileName, "explorer.exe", StringComparison.OrdinalIgnoreCase))
                    {
                        if (cachedExplorerPids != null) cachedExplorerPids.Add(pid);
                        return true;
                    }
                }
            }
            finally
            {
                CloseHandle(hProc);
            }
        }

        // Fallback: Process.GetProcessById
        try
        {
            var proc = Process.GetProcessById((int)pid);
            if (string.Equals(proc.ProcessName, "explorer", StringComparison.OrdinalIgnoreCase))
            {
                if (cachedExplorerPids != null) cachedExplorerPids.Add(pid);
                return true;
            }
        }
        catch {}

        return false;
    }

    private static void Main()
    {
        var thread = new System.Threading.Thread(() =>
        {
            IntPtr hDesk = IntPtr.Zero;
            try
            {
                hDesk = OpenInputDesktop(0, false, DESKTOP_ACCESS);
                if (hDesk == IntPtr.Zero)
                {
                    hDesk = OpenDesktop("default", 0, false, DESKTOP_ACCESS);
                }
                if (hDesk != IntPtr.Zero)
                {
                    bool setDesk = SetThreadDesktop(hDesk);
                    Log(string.Format("SetThreadDesktop: {0} (hDesk={1})", setDesk, hDesk));
                }
                else
                {
                    Log("Failed to open desktop, err=" + Marshal.GetLastWin32Error());
                }

                RunToggle(hDesk);
            }
            catch (Exception ex)
            {
                Log("Fatal error in thread: " + ex.Message);
            }
            finally
            {
                if (hDesk != IntPtr.Zero)
                {
                    CloseDesktop(hDesk);
                }
            }
        });

        thread.SetApartmentState(System.Threading.ApartmentState.MTA);
        thread.Start();
        thread.Join();
    }

    private static void RunToggle(IntPtr hDesk)
    {
        var taskbars = new HashSet<IntPtr>();
        var classBuf = new StringBuilder(256);

        var explorerPids = new HashSet<uint>();
        try
        {
            foreach (var p in Process.GetProcessesByName("explorer"))
            {
                explorerPids.Add((uint)p.Id);
            }
        }
        catch {}

        EnumWindowsProc enumCallback = (hWnd, lParam) =>
        {
            classBuf.Clear();
            GetClassName(hWnd, classBuf, classBuf.Capacity);
            string cls = classBuf.ToString();

            if (cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd")
            {
                uint pid = 0;
                GetWindowThreadProcessId(hWnd, out pid);
                if (IsExplorerProcess(pid, explorerPids))
                {
                    taskbars.Add(hWnd);
                }
            }
            return true;
        };

        // Strategy 1: Desktop enumeration if handle valid
        if (hDesk != IntPtr.Zero)
        {
            try
            {
                EnumDesktopWindows(hDesk, enumCallback, IntPtr.Zero);
            }
            catch (Exception ex) { Log("EnumDesktopWindows exception: " + ex.Message); }
        }

        // Strategy 2: EnumWindows on thread desktop
        if (taskbars.Count == 0)
        {
            try
            {
                EnumWindows(enumCallback, IntPtr.Zero);
            }
            catch (Exception ex) { Log("EnumWindows exception: " + ex.Message); }
        }

        // Strategy 3: Direct FindWindow
        if (taskbars.Count == 0)
        {
            try
            {
                IntPtr primary = FindWindow("Shell_TrayWnd", null);
                if (primary != IntPtr.Zero)
                {
                    uint pid = 0;
                    GetWindowThreadProcessId(primary, out pid);
                    if (IsExplorerProcess(pid, explorerPids))
                    {
                        taskbars.Add(primary);
                    }
                }
                IntPtr secondary = FindWindow("Shell_SecondaryTrayWnd", null);
                if (secondary != IntPtr.Zero)
                {
                    uint pid = 0;
                    GetWindowThreadProcessId(secondary, out pid);
                    if (IsExplorerProcess(pid, explorerPids))
                    {
                        taskbars.Add(secondary);
                    }
                }
            }
            catch (Exception ex) { Log("FindWindow exception: " + ex.Message); }
        }

        if (taskbars.Count == 0)
        {
            Log("No explorer taskbar windows found");
            return;
        }

        bool anyVisible = false;
        foreach (var hwnd in taskbars)
        {
            uint pid = 0;
            GetWindowThreadProcessId(hwnd, out pid);
            bool vis = IsWindowVisible(hwnd);
            Log(string.Format("Taskbar HWND: 0x{0:X}, PID: {1}, Visible: {2}", hwnd.ToInt64(), pid, vis));
            if (vis)
            {
                anyVisible = true;
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
