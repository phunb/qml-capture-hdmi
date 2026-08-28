HDMI Kiosk trên Raspberry Pi 4 (không desktop)
==============================================

Máy Windows KHÔNG tạo được file .exe chạy trên Pi (CPU ARM khác).
Binary phải build NGAY TRÊN Pi. Script trong thư mục này làm việc đó.

Yêu cầu
-------
- Raspberry Pi 4 (nên 4GB; 2GB chạy được nhưng chặt)
- Thẻ microSD 16GB+
- Màn HDMI cắm cổng HDMI của Pi
- USB capture (MS2109) + pedal/keypad HID
- Mạng LAN/Wi‑Fi để SSH từ PC
- Nguồn 5V/3A chính hãng (capture USB3 dễ sụt áp)

Bước 1 — Flash OS tối giản
--------------------------
1. Cài Raspberry Pi Imager trên PC:
   https://www.raspberrypi.com/software/
2. Chọn:
   - Device: Raspberry Pi 4
   - OS: Raspberry Pi OS (other) → Raspberry Pi OS Lite (64-bit)
     KHÔNG chọn Desktop / Full.
3. Bấm bánh răng (OS customisation):
   - hostname: hdmi-kiosk
   - user (ví dụ pi) + mật khẩu
   - bật SSH (password)
   - Wi‑Fi nếu không dùng LAN
4. Ghi ra thẻ, cắm Pi, bật nguồn.
5. Từ PC:  ping hdmi-kiosk.local   hoặc xem IP trên router.

Nếu copy từ Windows, trên Pi chạy một lần (tránh lỗi ^M):
  sed -i 's/\r$//' deploy/raspberrypi/*.sh

Bước 2 — Copy project sang Pi
-----------------------------
PowerShell (trong thư mục project):

  .\deploy\raspberrypi\copy-to-pi.ps1 -PiHost 192.168.x.x -PiUser pi

Hoặc thủ công:

  scp -r CMakeLists.txt src qml deploy pi@192.168.x.x:~/qml-capture-hdmi

Bước 3 — Build + cài kiosk (trên Pi)
------------------------------------
  ssh pi@192.168.x.x
  cd ~/qml-capture-hdmi
  chmod +x deploy/raspberrypi/*.sh
  sudo ./deploy/raspberrypi/install-raspberry-pi-kiosk.sh
  sudo reboot

Lần boot sau: Pi tự login TTY1 và mở app fullscreen (eglfs).
Không có Start menu / PIXEL / GNOME.

Chỉ build, chưa bật kiosk boot
------------------------------
  ./deploy/raspberrypi/build-on-pi.sh
  QT_QPA_PLATFORM=eglfs ./build-pi/hdmi-kiosk

Video lưu: USB (thư mục recorder/output trên USB). Không cắm USB thì không ghi được.
Log: ~/.local/share/HdmiKiosk/hdmi-kiosk.log
Thoát app bảo trì: Ctrl+Alt+Shift+Q rồi SSH.

Ghi chú Pi 4 / 2GB
------------------
Script bật HDMI_KIOSK_PI: ưu tiên 720p30, ghi NormalQuality.
Cắm capture vào cổng USB3 (xanh). User phải thuộc group video,input,render
(script đã usermod; logout/reboot mới có hiệu lực).
