# SafariCleaner

Tweak (jailbreak) cho **iOS 15.8.3 (rootless)** giúp xóa sâu dữ liệu & dấu vết Safari
chỉ bằng một nút bấm trong app **Settings**.

> **Mục đích dự kiến**: xóa sạch state trình duyệt giữa các phiên đăng ký tài khoản TikTok.
> Xóa dấu vết **trên thiết bị** không có nghĩa là né được mọi cơ chế chống spam phía máy chủ.
> Thay đổi IP thôi là chưa đủ trong hầu hết trường hợp.

---

## 1. Cấu trúc dự án

```
SafariCleaner/
├── Makefile
├── control
├── SafariCleaner.plist                 # Filter plist (target processes)
├── Tweak.x                             # Hook MobileSafari / MobileSafari.framework
├── SAFECleanerRoot.x                   # Helper chạy nền quyền root
├── layout/                             # Cấu trúc gói .deb
│   ├── DEBIAN/
│   ├── Applications/                   # Pref pane app
│   └── Library/...
└── SAFECleanerPref/                    # Preferences bundle (nút bấm trong Settings)
    ├── Makefile
    ├── control
    ├── SAFECleanerPref.plist
    ├── Resources/
    │   ├── Info.plist
    │   ├── en.lproj/
    │   │   ├── Root.strings
    │   │   └── safecleaner.strings
    │   ├── icon.png
    │   └── Root.plist
    └── root.plist
```

---

## 2. Cài Theos trên Windows

> Theos chính thức không hỗ trợ Windows, nhưng bạn có thể dùng **WSL2** (khuyến nghị).

### 2.1 Cài WSL2

```powershell
wsl --install
wsl --set-default-version 2
# Restart -> cài Ubuntu 22.04 từ Microsoft Store
```

### 2.2 Trong Ubuntu (WSL2)

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install git curl wget build-essential clang libssl-dev \
                    libcurl4-openssl-dev libplist-dev libplist-utils \
                    libavahi-compat-libdnssd-dev libusb-1.0-0-dev \
                    fakeroot dpkg dpkg-dev gnupg zip unzip
# iOS toolchain (từ Procursus):
sudo bash -c "$(wget -qO- https://apt.procurs.us/apt-key.gpg)" \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/procursus.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/procursus.gpg] https://apt.procurs.us/ bookworm main" \
    | sudo tee /etc/apt/sources.list.d/procursus.list
sudo apt update
sudo apt install -y odcctools xar ldid ldid-native
# Organya toolchain arm64e/arm64
curl -LO https://github.com/itsmeichigo/ios-toolchain-build/releases/latest/download/iOSToolchain.tar.xz
tar -xf iOSToolchain.tar.xz -C ~
export PATH=$PATH:$HOME/toolchain/bin
echo 'export PATH=$PATH:$HOME/toolchain/bin' >> ~/.bashrc
```

### 2.3 Cài Theos + logos

```bash
git clone --recursive https://github.com/theos/theos.git $THEOS
echo 'export THEOS=~/theos' >> ~/.bashrc
echo 'export PATH=$PATH:$THEOS/bin' >> ~/.bashrc
source ~/.bashrc
$THEOS/bin/update-theos
```

### 2.4 Cài ldid (để ký fake-sign cho rootless)

Trong Theos đã có sẵn `vendor/ios/toolchain/ldid` qua Procursus bootstrap.

### 2.5 Kiểm tra

```bash
$THEOS/bin/nic.pl
# nếu thấy prompt Nic với Template list -> OK
```

---

## 3. Build SafariCleaner

```bash
git clone <your-repo> ~/SafariCleaner
cd ~/SafariCleaner
make                    # build tweak
make package FINALPACKAGE=1
```

File `.deb` xuất hiện trong thư mục gốc, copy qua thiết bị bằng `scp`, Filza, hoặc qua Sileo.

---

## 4. Cài trên iPhone (Dopamine/palera1n rootless)

- iOS 15.8.3 với iPhone 7 → dùng **palera1n** (rootless) hoặc **Dopamine** (nếu được hỗ trợ).
- Sau khi jailbreak, cài **Sileo**.
- Trong Sileo: **Sources → Edit → Add** thêm URL repo của bạn (ví dụ `https://yourname.example/repo/`),
  rồi Add `SafariCleaner` và cài.
- Hoặc cài local bằng **Filza** (mở file .deb → Install).

---

## 5. Sử dụng

1. Mở **Settings** trên iPhone.
2. Kéo xuống dưới cùng → chọn **Safari Cleaner**.
3. Bấm nút **Wipe Safari Now**.
4. Tweak sẽ:
   - Quit Safari (`killall MobileSafari`).
   - Tạo backup profile ở `/var/mobile/Documents/SafariCleaner/backup-<timestamp>/`.
   - Xóa toàn bộ cookie/cookie storage, WebKit Cache, IndexedDB, LocalStorage, SessionStorage,
     History, Recently visited tiles, Reading List offline blob, Autofill, Service Worker registrations,
     URL cache pref, Web Inspector selections, SSL keys cho session Safari,
     safari.db / browser DB / WeChatOfflineResources / …
   - Quét thêm: `~/Library/Caches/com.apple.mobilesafari*`,
     `~/Library/Cookies/Cookies.binarycookies`,
     `~/Library/Safari/Bookmarks.plist`,
     `~/Library/Preferences/com.apple.mobilesafari.plist`,
     `~/Library/WebKit/WebsiteData/*`.
   - Reset các key liên quan trong `cfprefsd` liên quan đến Safari và WebKit.
   - Mở lại Safari với profile mới.

Nếu **Delete backup** bật: backup sẽ tự xóa sau khi xóa xong. Nếu tắt: giữ lại để khôi phục nếu cần.

---

## 6. Tuỳ chọn

- **Wipe Safari Now**: Thực hiện ngay.
- **Keep backup after wipe**: Bật/tắt có giữ backup.
- **Kill Safari background processes**: Bao gồm WebKit networking process.

---

## 7. Gỡ cài đặt

```bash
sudo apt remove safecleaner       # hoặc dùng Sileo
make uninstall
```

---

## 8. Cảnh báo quan trọng

Phần mềm này xóa cơ sở dữ liệu của Safari. **Hãy đăng xuất mọi tài khoản quan trọng trước**, vì
mọi phiên đăng nhập (Google, Facebook, Apple ID, ngân hàng...) sẽ bị xóa theo.

Tweak này chỉ xóa dấu vết trên thiết bị local, không:
- Đổi fingerprint thiết bị ở mức phần cứng (model, serial, MAC…).
- Đổi các yếu tố ngoài thiết bị mà máy chủ TikTok / bên thứ 3 có thể quan sát.
Đăng ký nhiều tài khoản có thể vi phạm Điều khoản dịch vụ của TikTok, và có rủi ro bị khóa vĩnh viễn.
