# HDMI Kiosk (Qt / QML)

Ứng dụng kiosk cho mini-PC: nhận tín hiệu HDMI, hiện trực tiếp lên màn hình cảm ứng, ghi thành file video và xem lại. Giao diện QML (frontend) + C++ Qt (backend) trong cùng một process để độ trễ thấp.

## Phần cứng cần có

Cổng HDMI trên mini-PC **thường là HDMI OUT** (xuất hình ra màn hình), không phải HDMI IN.

Nguồn HDMI (đầu thu, camera, máy khác…) phải vào một thiết bị **HDMI Capture**:

- Mini-PC công nghiệp có sẵn **HDMI IN** (xuất hiện thành `/dev/video0` hoặc camera Windows), hoặc
- USB HDMI capture (UVC): Cam Link, MacroSilicon 534d, AverMedia, Elgato, v.v.

Sơ đồ:

```
Nguồn HDMI  -->  HDMI IN / USB Capture  -->  mini-PC  -->  màn cảm ứng
                                              ^
                                              HID keyboard (nút tối giản)
```

App nhận capture như một camera, ưu tiên thiết bị tên có `HDMI`, `Capture`, `Cam Link`, `MacroSilicon`, `USB Video`.

## Tính năng

- Live preview HDMI toàn màn hình, kiosk (không thanh cửa sổ)
- Ghi MP4 (H.264 + AAC) vào thư mục Video/`HdmiKiosk`
- Thư viện xem lại / xóa video
- Cảm ứng + bàn phím HID
- Tự chọn capture, phát hiện mất tín hiệu (kể cả khung hình đen)
- Tự dừng ghi khi hết dung lượng hoặc quá thời lượng tối đa (mặc định 4 giờ)
- Windows: chặn Win, Alt+Tab, Ctrl+Esc, Alt+F4
- Tự chạy khi Windows/Linux khởi động (script trong `deploy/`)

## Cấu trúc

```
qml/                  frontend QML
src/                  backend C++
  CaptureController   HDMI preview + record
  RecordingManager    file video
  VideoLibraryModel   danh sách xem lại
  KioskController     fullscreen / khóa OS
  HidInputRouter      phím HID
deploy/windows|linux  autostart + kiosk
```

## Build

Yêu cầu: **Qt 6.5+** (Quick, QuickControls2, Multimedia; backend FFmpeg khuyến nghị).

### Windows (MSVC hoặc Ninja)

```bat
cmake -S . -B build -DCMAKE_PREFIX_PATH=C:/Qt/6.8.0/msvc2022_64
cmake --build build --config Release
```

Deploy DLL:

```bat
C:\Qt\6.8.0\msvc2022_64\bin\windeployqt.exe --qmldir qml build\Release\hdmi-kiosk.exe
```

### Linux

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

Gói thường cần: `qt6-base`, `qt6-declarative`, `qt6-multimedia`, FFmpeg/GStreamer tùy distro.

## Test trên Ubuntu 24.04 (Docker)

Build và smoke-test (load QML, không cần HDMI):

```bash
docker compose run --rm test
```

Windows:

```powershell
.\scripts\docker-test.ps1
```

Image `ubuntu:24.04`, Qt 6.8, `QT_QPA_PLATFORM=offscreen`. Test `smoke-load` thoát 0 nếu cửa sổ QML tạo được.

## Chạy

Chạy `hdmi-kiosk`. Cắm nguồn HDMI vào capture trước hoặc sau đều được (app theo dõi hotplug).

Video lưu tại:

- Windows: `%USERPROFILE%\Videos\HdmiKiosk\`
- Linux: `~/Videos/HdmiKiosk/`

Log: thư mục AppLocalData / `~/.local/share/HdmiKiosk/hdmi-kiosk.log`

## Thao tác

| Cảm ứng | HID keyboard |
| --- | --- |
| GHI HÌNH / DỪNG GHI | `R` / `F9` / `Space` (khi đang live) |
| THƯ VIỆN | `L` / `F2` |
| Quay lại live | `Esc` / `Backspace` / `F1` / `Home` |
| Phát video | `Enter` hoặc nút PHÁT |
| Chọn trong danh sách | `↑` `↓` |
| Tua khi phát | `←` `→` (Shift = 30s) |
| Tạm dừng khi phát | `Space` |
| Xóa video | `Del` |
| Đổi thiết bị capture | chạm tên thiết bị góc phải |
| Thoát kiosk (bảo trì) | `Ctrl+Alt+Shift+Q` |

Gán nhãn các phím trên HID keypad theo bảng trên.

Trong lúc đang ghi, app khóa về màn live (không mở thư viện) để tránh mất khung hình.

## Kiosk + tự chạy khi boot

### Windows

1. Tạo user Windows riêng (ví dụ `kiosk`), bật auto-login (`netplwiz`).
2. Build xong:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\windows\install-autostart.ps1 -ExePath "C:\path\to\hdmi-kiosk.exe"
```

3. (Tuỳ chọn) đọc `deploy\windows\kiosk-setup.ps1`. Windows 10/11 Pro có thể dùng Assigned Access / Shell Launcher nếu cần khóa Explorer hoàn toàn.

Gỡ:

```powershell
powershell -ExecutionPolicy Bypass -File deploy\windows\uninstall-autostart.ps1
```

### Linux (Ubuntu 24.04 kiosk)

Đóng gói trên Ubuntu **có mạng** (không làm được từ Windows):

```bash
./scripts/package-ubuntu-deb.sh
```

Mini-PC **không mạng** — copy USB rồi:

```bash
sudo ./dist/hdmi-kiosk-offline_1.0.0_amd64.run
sudo reboot
```

Máy tự login user `kiosk` và chạy app toàn màn hình (`cage`). Chi tiết: `deploy/linux/UBUNTU-KIOSK.txt`.

Cài từ source trên chính mini-PC:

```bash
sudo ./deploy/linux/install-ubuntu-kiosk.sh
sudo reboot
```

Chỉ autostart trên desktop sẵn có (không khóa GNOME):

```bash
chmod +x deploy/linux/*.sh
./deploy/linux/install-autostart.sh /path/to/hdmi-kiosk
```

## Bảo trì

`Ctrl+Alt+Shift+Q` → xác nhận → thoát app, trả máy về desktop. Log dùng để bắt lỗi capture/codec nếu không ghi được file.
