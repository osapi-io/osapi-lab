#!/usr/bin/env python3
"""Write a qcow2 disk image as a raw disk image, which Tart boots.

Usage: qcow2_to_raw.py <in.qcow2> <out.raw>

The hub has no qemu-img, so the lab reads qcow2 itself. It reads only what a
published cloud image uses: version 2 or 3, no backing file, no encryption,
no snapshots in use, zlib compression. It refuses every other image, and
leaves the clusters that are not allocated as holes in a sparse file.
"""

import struct
import sys
import zlib

MAGIC = b"QFI\xfb"
OFFSET_MASK = 0x00FFFFFFFFFFFE00
COMPRESSED = 1 << 62
ZERO = 1


def fail(message):
    sys.exit(f"qcow2_to_raw: {message}")


def main(src_path, dst_path):
    with open(src_path, "rb") as src:
        header = src.read(112)
        if header[:4] != MAGIC:
            fail("not a qcow2 image")
        (version, backing_offset, _, cluster_bits, size, crypt, l1_size,
         l1_offset) = struct.unpack(">IQIIQIIQ", header[4:48])
        if version not in (2, 3):
            fail(f"qcow2 version {version} is not supported")
        if backing_offset:
            fail("an image with a backing file is not supported")
        if crypt:
            fail("an encrypted image is not supported")
        if version == 3:
            incompatible = struct.unpack(">Q", header[72:80])[0]
            # Bit 0 is the dirty flag; it says only that refcounts may be
            # stale, which a read does not use.
            if incompatible & ~1:
                fail(f"incompatible features {incompatible:#x} are not supported")

        cluster = 1 << cluster_bits
        l2_entries = cluster // 8
        # Of a compressed L2 entry, the low bits are the host offset and the
        # bits above them, to bit 61, are the count of extra 512-byte sectors.
        csize_shift = 62 - (cluster_bits - 8)
        coffset_mask = (1 << csize_shift) - 1
        csize_mask = (1 << (cluster_bits - 8)) - 1

        src.seek(l1_offset)
        l1 = struct.unpack(f">{l1_size}Q", src.read(8 * l1_size))

        with open(dst_path, "wb") as dst:
            dst.truncate(size)
            zeros = bytes(cluster)
            for l1_index, l1_entry in enumerate(l1):
                l2_offset = l1_entry & OFFSET_MASK
                if not l2_offset:
                    continue
                src.seek(l2_offset)
                l2 = struct.unpack(f">{l2_entries}Q", src.read(cluster))
                for l2_index, entry in enumerate(l2):
                    guest = (l1_index * l2_entries + l2_index) * cluster
                    if guest >= size:
                        break
                    if entry & COMPRESSED:
                        host = entry & coffset_mask
                        sectors = ((entry >> csize_shift) & csize_mask) + 1
                        length = sectors * 512 - (host & 511)
                        src.seek(host)
                        data = zlib.decompressobj(-15).decompress(src.read(length), cluster)
                        if len(data) != cluster:
                            fail(f"a compressed cluster at {host:#x} is short")
                    else:
                        host = entry & OFFSET_MASK
                        if not host or entry & ZERO:
                            continue
                        src.seek(host)
                        data = src.read(cluster)
                    data = data[: size - guest]
                    if data != zeros[: len(data)]:
                        dst.seek(guest)
                        dst.write(data)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        fail("usage: qcow2_to_raw.py <in.qcow2> <out.raw>")
    main(sys.argv[1], sys.argv[2])
