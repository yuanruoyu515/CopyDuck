"""Package the app's own PNG artwork into an ICNS container, without extra dependencies."""
import pathlib
import struct
import sys

source, destination = map(pathlib.Path, sys.argv[1:])
entries = []
for code, size in [(b"icp4", 16), (b"icp5", 32), (b"icp6", 64), (b"ic07", 128),
                   (b"ic08", 256), (b"ic09", 512), (b"ic10", 1024),
                   (b"ic11", 32), (b"ic12", 64), (b"ic13", 256), (b"ic14", 512)]:
    data = (source / f"duck-{size}.png").read_bytes()
    entries.append(code + struct.pack(">I", len(data) + 8) + data)
payload = b"".join(entries)
destination.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
