#!/usr/bin/env python3
"""Composite the Android launcher icons from the Kenney plane sprite.

Regenerate with:  python3 tools/make_icons.py assets/sprites assets/icon

Pure stdlib (zlib + struct) so it runs anywhere without Pillow.
"""
import zlib
import struct
import math
import sys

SKY_TOP = (0x9A, 0xD5, 0xEC)
SKY_BOT = (0xE4, 0xF4, 0xFB)


def load_png(path):
    data = open(path, 'rb').read()
    pos, idat, plte, trns = 8, b'', None, None
    w = h = ct = None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, _bd, ct = struct.unpack('>IIBB', chunk[:10])
        elif typ == b'PLTE':
            plte = chunk
        elif typ == b'tRNS':
            trns = chunk
        elif typ == b'IDAT':
            idat += chunk
        pos += 12 + ln

    raw = zlib.decompress(idat)
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    stride = w * ch
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:
            for i in range(ch, stride):
                line[i] = (line[i] + line[i - ch]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line

    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        if ct == 3:
            idx = out[i]
            rgba[i * 4:i * 4 + 3] = plte[idx * 3:idx * 3 + 3]
            rgba[i * 4 + 3] = trns[idx] if (trns and idx < len(trns)) else 255
        elif ct == 6:
            rgba[i * 4:i * 4 + 4] = out[i * 4:i * 4 + 4]
        elif ct == 2:
            rgba[i * 4:i * 4 + 3] = out[i * 3:i * 3 + 3]
            rgba[i * 4 + 3] = 255
    return w, h, rgba


def save_png(path, w, h, rgba):
    raw = b''.join(b'\x00' + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))

    def chunk(typ, data):
        body = struct.pack('>I', len(data)) + typ + data
        return body + struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)


def sample(src, sw, sh, u, v):
    """Bilinear sample with premultiplied alpha, so edges don't fringe dark."""
    x = min(max(u * sw - 0.5, 0.0), sw - 1.0)
    y = min(max(v * sh - 0.5, 0.0), sh - 1.0)
    x0, y0 = int(x), int(y)
    x1, y1 = min(x0 + 1, sw - 1), min(y0 + 1, sh - 1)
    fx, fy = x - x0, y - y0
    acc = [0.0] * 4
    for px, py, wgt in ((x0, y0, (1 - fx) * (1 - fy)), (x1, y0, fx * (1 - fy)),
                        (x0, y1, (1 - fx) * fy), (x1, y1, fx * fy)):
        o = (py * sw + px) * 4
        a = src[o + 3] / 255.0
        acc[0] += src[o] * a * wgt
        acc[1] += src[o + 1] * a * wgt
        acc[2] += src[o + 2] * a * wgt
        acc[3] += a * wgt
    if acc[3] <= 0.0001:
        return (0, 0, 0, 0)
    return (int(acc[0] / acc[3]), int(acc[1] / acc[3]), int(acc[2] / acc[3]), int(acc[3] * 255))


def corner_alpha(x, y, size, radius):
    cx = radius if x < radius else (size - 1 - radius if x > size - 1 - radius else x)
    cy = radius if y < radius else (size - 1 - radius if y > size - 1 - radius else y)
    d = math.hypot(x - cx, y - cy)
    if d <= radius - 1:
        return 1.0
    if d >= radius:
        return 0.0
    return radius - d


def gradient(size, rounded=0):
    px = bytearray(size * size * 4)
    for y in range(size):
        t = y / (size - 1)
        r = int(SKY_TOP[0] + (SKY_BOT[0] - SKY_TOP[0]) * t)
        g = int(SKY_TOP[1] + (SKY_BOT[1] - SKY_TOP[1]) * t)
        b = int(SKY_TOP[2] + (SKY_BOT[2] - SKY_TOP[2]) * t)
        for x in range(size):
            a = int(255 * corner_alpha(x, y, size, rounded)) if rounded else 255
            o = (y * size + x) * 4
            px[o], px[o + 1], px[o + 2], px[o + 3] = r, g, b, a
    return px


def blit(dst, size, src, sw, sh, target_w):
    """Draw src scaled to target_w wide, centred, over dst."""
    th = int(round(sh * (target_w / sw)))
    ox = (size - target_w) // 2
    oy = (size - th) // 2
    for y in range(th):
        for x in range(target_w):
            r, g, b, a = sample(src, sw, sh, (x + 0.5) / target_w, (y + 0.5) / th)
            if a == 0:
                continue
            o = ((oy + y) * size + (ox + x)) * 4
            af = a / 255.0
            dst[o] = int(dst[o] * (1 - af) + r * af)
            dst[o + 1] = int(dst[o + 1] * (1 - af) + g * af)
            dst[o + 2] = int(dst[o + 2] * (1 - af) + b * af)
            dst[o + 3] = max(dst[o + 3], a)


def main():
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    sw, sh, plane = load_png(f"{src_dir}/plane1.png")

    # Legacy square icon: plane on the sky gradient, gently rounded.
    legacy = gradient(192, rounded=34)
    blit(legacy, 192, plane, sw, sh, 132)
    save_png(f"{out_dir}/icon_192.png", 192, 192, legacy)

    # Adaptive background: full-bleed gradient, the system applies the mask.
    save_png(f"{out_dir}/icon_bg_432.png", 432, 432, gradient(432))

    # Adaptive foreground: plane kept inside the 66% safe zone.
    foreground = bytearray(432 * 432 * 4)
    blit(foreground, 432, plane, sw, sh, 224)
    save_png(f"{out_dir}/icon_fg_432.png", 432, 432, foreground)

    print("wrote icon_192.png, icon_bg_432.png, icon_fg_432.png")


if __name__ == "__main__":
    main()
