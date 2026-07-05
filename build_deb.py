#!/usr/bin/env python3
"""
build_deb.py - Đóng gói deb cho rootless jailbreak iOS.
Không cần toolchain Linux / Theos. Chạy trên Windows / macOS / Linux.

Cấu trúc deb (chuẩn dpkg):
  <name>_<version>_<arch>.deb
  ├── debian-binary         (chứa "2.0")
  ├── control.tar.gz        (chứa DEBIAN/control, preinst, postinst, prerm, postrm)
  └── data.tar.gz           (chứa var/jb/... các file cài vào thiết bị)
"""
import gzip
import os
import shutil
import struct
import sys
import tarfile
import time
import io


def make_tar_gz_with_owners(src_root, files, out_path):
    """Tạo tar.gz với owner=root:root cho từng file."""
    with tarfile.open(out_path, "w:gz", format=tarfile.GNU_FORMAT) as tar:
        for arcname in files:
            full_path = os.path.join(src_root, arcname)
            tar.add(full_path, arcname=arcname, recursive=False)


def collect_files(root):
    """Liệt kê tất cả file (relative) dưới root."""
    out = []
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            out.append(rel)
    return sorted(out)


def make_ar_archive(members, out_path):
    """
    Tạo file .deb (ar archive) bằng tay (không cần bin 'ar' của Linux).
    Format ar: mỗi member có header 60 bytes + nội dung, padding cho even.
    """
    # Global header
    with open(out_path, "wb") as out:
        out.write(b"!<arch>\n")

        for name, data in members:
            # AR header fields (mỗi field 16 bytes ngoại trừ 60-byte total)
            name_b = name.encode("ascii")
            if len(name_b) > 16:
                name_b = name_b[:16]
            else:
                # ARFID-style: kết thúc bằng '/'
                name_b = name_b + b"/" + b" " * (16 - len(name_b) - 1)

            size = len(data)
            mtime = int(time.time())

            # Standard AR header (60 bytes)
            # name[16], date[12], uid[6], gid[6], mode[8], size[10], fmag[2]
            header = (
                name_b +
                b"%12d" % mtime +
                b"0     " +
                b"0     " +
                b"100644  " +
                b"%-10d" % size +
                b"\x60\n"  # ARFMAG (backtick + newline)
            )
            assert len(header) == 60, f"Header wrong size: {len(header)}"

            out.write(header)
            out.write(data)
            # Pad to even boundary (AR requirement)
            if size % 2 == 1:
                out.write(b"\n")


def build():
    project_root = os.path.dirname(os.path.abspath(__file__))
    layout_dir = os.path.join(project_root, "layout")
    packages_dir = os.path.join(project_root, "packages")
    os.makedirs(packages_dir, exist_ok=True)

    # Clean previous artifacts
    for f in os.listdir(packages_dir):
        os.remove(os.path.join(packages_dir, f))

    # Read version & arch from control file
    control_path = os.path.join(layout_dir, "DEBIAN", "control")
    with open(control_path, encoding="utf-8") as f:
        control_text = f.read()
    version = "1.0.0"
    arch = "iphoneos-arm64"
    package_name = "safecleaner"

    for line in control_text.splitlines():
        if line.startswith("Version:"):
            version = line.split(":", 1)[1].strip()
        elif line.startswith("Package:"):
            package_name = line.split(":", 1)[1].strip()

    deb_filename = f"{package_name}_{version}_{arch}.deb"

    # Collect files (control.tar.gz = DEBIAN/, data.tar.gz = everything else)
    all_files = collect_files(layout_dir)

    # control.tar.gz: only DEBIAN/*
    control_files = [f for f in all_files if f.startswith("DEBIAN/")]

    # data.tar.gz: everything except DEBIAN/
    data_files = [f for f in all_files if not f.startswith("DEBIAN/")]

    print(f"==> Tao data.tar.gz ({len(data_files)} files)")
    data_tar_path = os.path.join(packages_dir, "data.tar.gz")
    make_tar_gz_with_owners(layout_dir, data_files, data_tar_path)

    print(f"==> Tao control.tar.gz ({len(control_files)} files)")
    control_tar_path = os.path.join(packages_dir, "control.tar.gz")
    make_tar_gz_with_owners(layout_dir, control_files, control_tar_path)

    # debian-binary
    print("==> Tao debian-binary")
    binary_data = b"2.0\n"

    # AR archive
    deb_path = os.path.join(packages_dir, deb_filename)
    print(f"==> Dong goi {deb_filename}")
    with open(data_tar_path, "rb") as f:
        data_tar_bytes = f.read()
    with open(control_tar_path, "rb") as f:
        control_tar_bytes = f.read()

    make_ar_archive(
        [
            ("debian-binary", binary_data),
            ("control.tar.gz", control_tar_bytes),
            ("data.tar.gz", data_tar_bytes),
        ],
        deb_path,
    )

    print(f"\n[OK] HOAN TAT: packages/{deb_filename}")
    size = os.path.getsize(deb_path)
    print(f"   Kích thước: {size:,} bytes ({size/1024:.1f} KB)")
    return deb_path


if __name__ == "__main__":
    build()