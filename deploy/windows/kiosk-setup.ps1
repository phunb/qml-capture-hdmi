# Optional Windows kiosk hardening (run as Administrator).
# App already runs fullscreen, stays on top, and blocks Win/Alt+Tab.
# This script additionally tries to hide Explorer chrome after logon.

$ErrorActionPreference = "Stop"

Write-Host "Cấu hình kiosk Windows cho HDMI Kiosk..."

# Auto-restart Explorer is left intact so admin can still recover after Ctrl+Alt+Shift+Q.
# Hide taskbar auto via the app window (always-on-top fullscreen) is the primary lock.

$desktop = [Environment]::GetFolderPath("Desktop")
Write-Host "Không thay đổi Windows Shell (Explorer) để tránh khóa máy nếu app lỗi."
Write-Host "Khuyến nghị:"
Write-Host "  1. Tạo user Windows riêng tên kiosk"
Write-Host "  2. Bật auto-login cho user đó"
Write-Host "  3. Chạy install-autostart.ps1"
Write-Host "  4. Gỡ bàn phím thừa; chỉ để HID keypad/keyboard tối giản"
Write-Host "  5. Windows 10/11 Pro: Assigned Access / Shell Launcher nếu cần khóa cứng hơn"
Write-Host ""
Write-Host "Desktop hiện tại: $desktop"
