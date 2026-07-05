#!/usr/bin/env bash
# setup-wsl.sh
# Script cài đặt Theos + iOS toolchain + SafariCleaner build env trong WSL2 (Ubuntu)
# Chạy 1 lần:  bash setup-wsl.sh
set -euo pipefail

echo "=========================================="
echo " SafariCleaner - WSL setup script"
echo "=========================================="

# 1. Cập nhật & cài dependencies cơ bản
sudo apt update
sudo apt -y upgrade
sudo apt -y install git curl wget build-essential clang \
                    libssl-dev libcurl4-openssl-dev libplist-dev \
                    libplist-utils libavahi-compat-libdnssd-dev \
                    libusb-1.0-0-dev fakeroot dpkg dpkg-dev gnupg \
                    zip unzip xz-utils

# 2. Thêm Procursus repo (chứa toolchain iOS đã được deb hóa)
if ! grep -q "apt.procurs.us" /etc/apt/sources.list.d/procursus.list 2>/dev/null; then
    curl -fsSL https://apt.procurs.us/apt-key.gpg | sudo gpg --dearmor \
        -o /etc/apt/trusted.gpg.d/procursus.gpg
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/procursus.gpg] https://apt.procurs.us/ bookworm main" \
        | sudo tee /etc/apt/sources.list.d/procursus.list
    sudo apt update
fi

sudo apt -y install odcctools ldid

# 3. iOS toolchain (Clang cho arm64)
TOOLCHAIN_DIR="$HOME/toolchain"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
    mkdir -p "$TOOLCHAIN_DIR"
    echo "Downloading iOS toolchain (có thể mất vài phút)..."
    curl -L -o /tmp/iOSToolchain.tar.xz \
        https://github.com/itsmeichigo/ios-toolchain-build/releases/latest/download/iOSToolchain.tar.xz
    tar -xf /tmp/iOSToolchain.tar.xz -C "$TOOLCHAIN_DIR"
    echo "export PATH=\$PATH:$TOOLCHAIN_DIR/bin" >> ~/.bashrc
fi

# 4. Theos
THEOS_DIR="$HOME/theos"
if [ ! -d "$THEOS_DIR" ]; then
    git clone --recursive https://github.com/theos/theos.git "$THEOS_DIR"
    echo "export THEOS=$THEOS_DIR" >> ~/.bashrc
    echo "export PATH=\$PATH:$THEOS_DIR/bin" >> ~/.bashrc
fi

# 5. Apply env ngay trong session này
export THEOS="$THEOS_DIR"
export PATH="$PATH:$TOOLCHAIN_DIR/bin:$THEOS_DIR/bin"

# 6. Kiểm tra
echo
echo "Verifying installation..."
"$THEOS/bin/update-theos" || true
command -v clang || echo "WARNING: clang missing"
command -v ldid || echo "WARNING: ldid missing"

cat <<'EOF'

==========================================
 Setup complete!
==========================================
Sau khi đóng terminal, mở lại để load PATH, rồi:

    cd ~/SafariCleaner
    make package FINALPACKAGE=1

Sau khi build, copy file .deb sang iPhone (qua Sileo / Filza / scp).
EOF