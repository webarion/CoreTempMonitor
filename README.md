# Core Temp Monitor

![Core Temp Monitor](screenshot.jpg)

A graphical CPU temperature monitor with beautiful translucent interface, written in PureBasic. Works in conjunction with Core Temp to monitor CPU core temperatures and loads in real-time.

## ✨ Features

- **🎨 Elegant Interface** - Frameless translucent window with smooth animations
- **📊 Data Visualization** - Colored temperature bars and real-time graphs
- **🔢 Detailed Information** - Temperature, load, frequency for each core
- **⚡ Lightweight** - Minimal resource consumption
- **🖱️ Easy Control** - Window dragging, system tray minimization
- **🌐 Cross-Platform** - Supports Windows, Linux, macOS

## 🛠 Technical Details

- **Programming Language**: PureBasic
- **Graphics Engine**: Vector Drawing
- **Monitoring Library**: CoreTempInfo.dll
- **Multithreading**: Asynchronous data updates
- **Interface**: Translucent windows with compositing support

## 📦 Installation & Usage

### Requirements
- Installed [Core Temp](https://www.alcpu.com/CoreTemp/) software
- PureBasic compiler (for building from source)

### Running
1. Ensure Core Temp is running and collecting data
2. Launch `CoreTempMonitor.exe`
3. The program will appear in system tray

## 🎮 Controls

- **Left click on window** - Drag to move
- **Right click on window** - Context menu
- **Left click on tray icon** - Show/hide window
- **Right click on tray icon** - Control menu

## 🎯 Customization

The code includes configurable settings:
- Window size and transparency
- Color schemes for cores
- Fonts and text sizes
- Graph and grid parameters

## 🤝 Compatibility

- **Processors**: Intel and AMD multi-core
- **OS**: Windows 7+
- **Core Temp**: version 1.0+

## 📄 License
Free

---

*Developed by Webarion · Version 1.0b*
