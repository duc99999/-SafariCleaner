#!/usr/bin/env python3
"""verify_deb.py - Verify deb file structure."""
import os
import sys
import tarfile

deb_path = sys.argv[1] if len(sys.argv) > 1 else "packages/com.duc.safecleaner_1.0.0_iphoneos-arm64.deb"

print(f"=== Verifying: {deb_path} ===\n")
print(f"File size: {os.path.getsize(deb_path):,} bytes\n")

with open(deb_path, "rb") as f:
    magic = f.read(8)
    print(f"AR magic: {magic!r}")
    assert magic == b"!<arch>\n", "Not an AR archive!"
    print("[OK] Valid AR archive\n")

# Extract data.tar.gz and list contents
print("=== Members in .deb ===")
with open(deb_path, "rb") as f:
    f.read(8)  # Skip magic
    for i in range(3):
        header = f.read(60)
        if len(header) < 60:
            break
        name = header[:16].decode("ascii", errors="ignore").strip().rstrip("/")
        size = int(header[48:58].decode("ascii").strip())
        print(f"  - {name} ({size:,} bytes)")
        f.read(size)
        if size % 2 == 1:
            f.read(1)

print()
print("=== Data files (what actually installs to iPhone) ===")
data_tar_bytes = None
with open(deb_path, "rb") as f:
    f.read(8)
    for i in range(3):
        header = f.read(60)
        name = header[:16].decode("ascii", errors="ignore").strip().rstrip("/")
        size = int(header[48:58].decode("ascii").strip())
        if name == "data.tar.gz":
            data_tar_bytes = f.read(size)
            break
        f.read(size)
        if size % 2 == 1:
            f.read(1)

if data_tar_bytes:
    import io
    with tarfile.open(fileobj=io.BytesIO(data_tar_bytes), mode="r:gz") as tar:
        members = tar.getmembers()
        for m in members:
            print(f"  {m.name}")
        print()
        # Check: any rootful path?
        rootful = [m.name for m in members if m.name.startswith("./Library/") or m.name.startswith("./usr/")]
        if rootful:
            print(f"[FAIL] Found {len(rootful)} rootful paths!")
            for r in rootful:
                print(f"  BAD: {r}")
            sys.exit(1)
        else:
            print("[OK] All paths are rootless (under /var/jb/)")
else:
    print("[FAIL] data.tar.gz not found in deb")
    sys.exit(1)