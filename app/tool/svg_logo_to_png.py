#!/usr/bin/env python3
"""Turns the Canva-style logo.svg (two embedded PNGs: a colour image and a
greyscale mask) into a transparent PNG, since flutter_svg does not support SVG
masks. Pure Python, no packages.

    python3 tool/svg_logo_to_png.py logo.svg assets/images/brand_logo.png [width]

The result is resampled with macOS `sips` when [width] is given (default 1100).
"""
import base64, re, struct, subprocess, sys, tempfile, zlib, os

def read_png(path):
    d = open(path, 'rb').read()
    i = 8; idat = b''
    while i < len(d):
        n, = struct.unpack('>I', d[i:i+4]); t = d[i+4:i+8]
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', d[i+8:i+18])
        elif t == b'IDAT': idat += d[i+8:i+8+n]
        i += 12 + n
    bpp = {0: 1, 2: 3, 6: 4}[ct]
    raw = zlib.decompress(idat); stride = w * bpp
    rows = []; prev = bytearray(stride); p = 0
    for y in range(h):
        f = raw[p]; line = bytearray(raw[p+1:p+1+stride]); p += 1 + stride
        if f == 1:
            for x in range(bpp, stride): line[x] = (line[x] + line[x-bpp]) & 255
        elif f == 2:
            line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        elif f == 3:
            for x in range(stride):
                a = line[x-bpp] if x >= bpp else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x-bpp] if x >= bpp else 0; b = prev[x]; c = prev[x-bpp] if x >= bpp else 0
                pa = abs(b - c); pb = abs(a - c); pc = abs(a + b - 2*c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(line); prev = line
    return w, h, ct, rows


def main():
    svg, out = sys.argv[1], sys.argv[2]
    width = sys.argv[3] if len(sys.argv) > 3 else '1100'
    parts = re.findall(r'base64,([A-Za-z0-9+/=]+)', open(svg).read())
    if len(parts) != 2:
        sys.exit('expected two embedded PNGs (mask + colour), found %d' % len(parts))
    with tempfile.TemporaryDirectory() as d:
        paths = []
        for i, b in enumerate(parts):
            p = os.path.join(d, 'part%d.png' % i)
            open(p, 'wb').write(base64.b64decode(b))
            paths.append(p)
        w, h, ct0, mask = read_png(paths[0])
        w2, h2, ct1, color = read_png(paths[1])
        assert (w, h) == (w2, h2) and ct0 == 0 and ct1 == 2, 'unexpected image formats'
        rows = bytearray()
        for y in range(h):
            row = bytearray(w * 4)
            row[0::4] = color[y][0::3]; row[1::4] = color[y][1::3]
            row[2::4] = color[y][2::3]; row[3::4] = mask[y]
            rows += b'\x00' + row
        def chunk(t, data):
            return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)
        full = os.path.join(d, 'full.png')
        open(full, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 9)) + chunk(b'IEND', b''))
        subprocess.run(['sips', '--resampleWidth', width, full, '--out', out], check=True, capture_output=True)
    print('wrote', out)

main()
