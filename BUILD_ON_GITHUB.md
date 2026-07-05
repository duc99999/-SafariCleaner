# Hướng dẫn build tự động trên GitHub (không cần máy Ubuntu)

Bạn không cần cài WSL hay Ubuntu. Mọi thứ chạy trên server miễn phí của GitHub.

## 1. Tạo tài khoản GitHub (nếu chưa có)

Vào https://github.com và đăng ký (miễn phí).

## 2. Tạo repository mới

1. Vào https://github.com/new
2. Repository name: `SafariCleaner`
3. Chọn **Private** (nếu không muốn public) hoặc **Public**
4. Bấm **Create repository**

## 3. Upload code lên GitHub

### Cách A: Giao diện web (đơn giản nhất)

1. Trong repo vừa tạo, bấm **uploading an existing file** (hoặc kéo file).
2. Mở File Explorer tới `C:\Users\DUCA\Desktop\Code iphone\SafariCleaner`.
3. Chọn **tất cả** file và folder (trừ `.theos` nếu có).
4. Kéo thả vào trang web, commit.

### Cách B: Dùng git (PowerShell)

```powershell
cd "C:\Users\DUCA\Desktop\Code iphone\SafariCleaner"
git init
git add .
git commit -m "Initial SafariCleaner"
git branch -M main
git remote add origin https://github.com/<user-cua-ban>/SafariCleaner.git
git push -u origin main
```

Lưu ý: thay `<user-cua-ban>` bằng tên GitHub của bạn.

## 4. Kích hoạt build

Sau khi push code lên:

1. Vào repo trên GitHub.
2. Bấm tab **Actions** (ở thanh menu trên cùng).
3. Lần đầu, GitHub có thể hiện thông báo "Workflows aren't being run on forked repositories". Bấm **I understand my workflows, go ahead and enable them** nếu thấy.
4. Bấm workflow **Build SafariCleaner** ở bên trái → bấm **Run workflow** → **Run workflow**.
5. Đợi 2-5 phút. Job sẽ hiện dấu tích xanh lá nếu thành công, dấu X đỏ nếu lỗi.

## 5. Tải file `.deb`

1. Sau khi job xanh lá, bấm vào job đó.
2. Kéo xuống cuối trang, phần **Artifacts**.
3. Bấm **SafariCleaner-debs** → file ZIP tải về.
4. Giải nén ZIP, bạn sẽ có:
   - `safecleaner_*.deb`
   - `safecleaner.pref_*.deb`
   - `Packages` (dùng cho Sileo repo nếu muốn)
   - `Packages.gz`

## 6. Copy sang iPhone

Dùng **Filza** (cài từ Sileo trên iPhone đã jailbreak):

1. Bật HTTP Server trong Filza (Settings tab → Web Server).
2. Trên iPhone ghi nhớ URL hiển thị (ví dụ `http://192.168.1.xx:8080`).
3. Từ trình duyệt trên PC, vào URL đó.
4. Upload 2 file `.deb` vào thư mục `/var/mobile/Documents/`.

Cách khác: dùng **afc2d** / **usbmuxd**:

```powershell
# Trong PowerShell, cài qua scoop (cài scoop 1 lần)
irm get.scoop.sh | iex
scoop install libimobiledevice
scoop install usbmuxd
idevice_id -l          # tìm UDID iPhone
```

Hoặc qua SSH nếu đã có OpenSSH trên iPhone:

```bash
# Trong WSL Ubuntu (cài nhanh bằng wsl --install nếu chưa có)
sudo apt install -y libimobiledevice-utils
iproxy 2222 22
scp -P 2222 *.deb [email protected]:/var/mobile/Documents/
```

## 7. Cài trên iPhone

1. Mở Filza → `/var/mobile/Documents/` → bấm vào `safecleaner_*.deb` → **Install**.
2. Lặp lại với `safecleaner.pref_*.deb`.
3. **Respring** (Reboot Userspace).
4. Mở Settings → Safari Cleaner → bấm **Wipe Safari Now**.

## 8. Build lại sau khi sửa code

Mỗi lần bạn sửa code và push lên GitHub, workflow tự động chạy lại. Bạn chỉ cần:

- Vào tab **Actions**.
- Đợi job chạy xong.
- Tải artifact mới về.

Không cần cài thêm gì trên máy Windows.

---

## Mẹo: tạo tag để đóng gói thành Release

Nếu bạn muốn mỗi lần build thành công đều có file `.deb` dễ tải qua Release:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

Workflow sẽ tự tạo GitHub Release tên **v1.0.0** và gắn file `.deb` vào đó. Bạn có thể share link Release cho người khác tải trực tiếp.

---

## Troubleshooting

### Job báo đỏ (build fail)

1. Bấm vào job bị đỏ → bấm vào step **Build tweak** → đọc log.
2. Thường là do dependency SDK iOS chưa tải được. Tôi đã thêm fallback trong workflow, nhưng nếu Procursus release thay đổi URL thì cần cập nhật lại.

### Không thấy workflow

Đảm bảo file `.github/workflows/build.yml` có trong repo. Bấm tab **Actions** → nó sẽ hiện "Workflows" list.

### Download artifact bị chặn

Bạn cần đăng nhập GitHub khi bấm Download. Nếu repo là **private**, chỉ bạn mới tải được.

### Build thành công nhưng .deb bị lỗi khi cài

Có thể là lỗi runtime trên thiết bị, không phải lỗi compile. Đọc lại log install trong Sileo/Filza và báo lại cho tôi kèm:
- iOS version + jailbreak tool (Dopamine / palera1n / checkra1n).
- Log error khi cài.