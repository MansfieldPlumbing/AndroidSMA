global using Subsystem.Device;
global using Subsystem.Capabilities.Bluetooth;
global using Subsystem.Capabilities.Hardware;
global using Subsystem.Capabilities.Surface;
global using Subsystem.Capabilities.Usb;
global using Subsystem.Capabilities.Core;
global using Subsystem.Vom;

namespace Subsystem.Device
{
    public static class Power
    {
        public static BatteryStatusRecord GetBatteryStatus() => Subsystem.Capabilities.Hardware.Power.GetBatteryStatus();
    }
    public static class Info
    {
        public static DeviceInfoRecord GetDeviceInfo() => Subsystem.Capabilities.Hardware.Info.GetDeviceInfo();
    }
    public static class Storage
    {
        public static StorageInfoRecord GetStorageInfo() => Subsystem.Capabilities.Hardware.Storage.GetStorageInfo();
    }
    public static class Memory
    {
        public static MemoryInfoRecord GetMemoryInfo() => Subsystem.Capabilities.Hardware.Memory.GetMemoryInfo();
    }
    public static class Sensors
    {
        public static System.Collections.Generic.List<SensorRecord> GetSensors() => Subsystem.Capabilities.Hardware.Sensors.GetSensors();
    }
    public static class Network
    {
        public static NetworkInfoRecord GetNetworkInfo() => Subsystem.Capabilities.Hardware.Network.GetNetworkInfo();
    }
    public static class Torch
    {
        public static void SetFlashlight(string state = "Toggle") => Subsystem.Capabilities.Hardware.Torch.SetFlashlight(state);
    }
    public static class Haptics
    {
        public static void Vibrate(int durationMs) => Subsystem.Capabilities.Hardware.Haptics.Vibrate(durationMs);
    }
    public static class Audio
    {
        public static System.Collections.Generic.Dictionary<string, object> GetAudioVolume() => Subsystem.Capabilities.Hardware.Audio.GetAudioVolume();
        public static void SetAudioVolume(string stream, int level) => Subsystem.Capabilities.Hardware.Audio.SetAudioVolume(stream, level);
        public static void PlayBeep() => Subsystem.Capabilities.Hardware.Audio.PlayBeep();
    }
    public static class Input
    {
        public static string InvokeTap(float x, float y) => Subsystem.Capabilities.Hardware.Input.InvokeTap(x, y);
        public static string InvokeSwipe(float x1, float y1, float x2, float y2, long durationMs) => Subsystem.Capabilities.Hardware.Input.InvokeSwipe(x1, y1, x2, y2, durationMs);
    }
    public static class Clipboard
    {
        public static string GetClipboardText() => Subsystem.Capabilities.Surface.Clipboard.GetClipboardText();
        public static void SetClipboardText(string text) => Subsystem.Capabilities.Surface.Clipboard.SetClipboardText(text);
    }
    public static class Notifications
    {
        public static System.Collections.Generic.List<NotificationMessageRecord> GetAndroidMessages() => Subsystem.Capabilities.Surface.Notifications.GetAndroidMessages();
        public static void SendNotification(string title, string text) => Subsystem.Capabilities.Surface.Notifications.SendNotification(title, text);
    }
    public static class Display
    {
        public static DisplayInfoRecord GetDisplayInfo() => Subsystem.Capabilities.Surface.Display.GetDisplayInfo();
        public static string GetScreenshot() => Subsystem.Capabilities.Surface.Display.GetScreenshot();
    }
    public static class Apps
    {
        public static System.Collections.Generic.List<InstalledAppRecord> GetInstalledApps(bool includeSystem = false) => Subsystem.Capabilities.Surface.Apps.GetInstalledApps(includeSystem);
    }
    public static class Shell
    {
        public static void ShowToast(string message, bool isLong) => Subsystem.Capabilities.Surface.Shell.ShowToast(message, isLong);
        public static void StartIntent(string uriString) => Subsystem.Capabilities.Surface.Shell.StartIntent(uriString);
    }
}
