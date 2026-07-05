# Hướng dẫn build & cài đặt SafariCleaner

## Yêu cầu
- iPhone 7, iOS 15.8.3, jailbreak **rootless** (palera1n hoặc Dopamine).
- Máy tính Windows 10/11 có WSL2 (Ubuntu 22.04 hoặc mới hơn).
- Cáp USB để copy `.deb` qua iPhone.

## Bước 1 — Chuẩn bị WSL2

Mở **PowerShell với quyền Admin**:

```powershell
wsl --install
# Restart máy
wsl --set-default-version 2
```

Mở **Ubuntu** từ Start menu.

## Bước 2 — Chạy setup script

Trong Ubuntu:

```bash
mkdir -p ~/SafariCleaner
# Copy toàn bộ thư mục dự án vào ~/SafariCleaner (dùng File Explorer WSL \\wsl$\Ubuntu\home\<user>\SafariCleaner)
cd ~/SafariCleaner
chmod +x setup-wsl.sh
bash setup-wsl.sh
```

Script sẽ tự động cài: clang, ldid, Theos, iOS toolchain, Procursus repo.

Sau khi xong, **đóng và mở lại terminal** để PATH được load.

## Bước 3 — Build tweak

```bash
cd ~/SafariCleaner
make package FINALPACKAGE=1
```

Nếu thành công, bạn sẽ có 2 file:
- `safecleaner_1.0.0_iphoneos-arm64.deb`
- `safecleaner.pref_1.0.0_iphoneos-arm64.deb`

## Bước 4 — Copy .deb sang iPhone

Có 3 cách:

### Cách A: Qua mạng LAN (khuyến nghị)

Trên iPhone cài **Filza** từ Sileo. Mở Filza → bật Web Server (Settings → HTTP Server).
Truy cập URL từ trình duyệt trên PC, upload `.deb` lên `/var/mobile/Documents/`.

### Cách B: Qua SSH (afc2d / usbmuxd)

```bash
# Trên Windows cài libimobiledevice / usbmuxd / ifuse
# Trong WSL:
sudo apt install -y libimobiledevice-utils ifuse
iproxy 2222 22 &
scp -P 2222 safecleaner_*.deb [email protected]:/var/mobile/Documents/
```

### Cách C: Qua Sileo repo (khi bạn muốn public)

Upload 2 file .deb lên một host (ví dụ GitHub Releases / droplet của bạn) rồi tạo `Packages.gz`. Trong Sileo thêm source URL.

## Bước 5 — Cài trên iPhone

Mở **Filza** → vào `/var/mobile/Documents/` → bấm vào `safecleaner_*.deb` → **Install**.

Cài xong, **respring** (Reboot Userspace).

## Bước 6 — Sử dụng

1. Mở **Settings**.
2. Kéo xuống dưới cùng → **Safari Cleaner**.
3. Bấm **Wipe Safari Now** → confirm.
4. Chờ khoảng 3-5 giây, Safari sẽ tự thoát, wipe xong và mở lại với profile trống.

## Kiểm tra wipe có sạch không

Sau khi wipe, mở Safari vào `https://www.whatismybrowser.com/`:
- User-Agent phải về mặc định của iPhone Safari.
- Tabs / Recently visited trống.
- `tiktok.com` không còn cookie cũ.

## Gỡ cài

Trong Sileo → tìm `SafariCleaner` → **Modify → Uninstall**.

Hoặc qua SSH:
```bash
sudo apt remove safecleaner
sudo apt remove safecleaner.pref
```