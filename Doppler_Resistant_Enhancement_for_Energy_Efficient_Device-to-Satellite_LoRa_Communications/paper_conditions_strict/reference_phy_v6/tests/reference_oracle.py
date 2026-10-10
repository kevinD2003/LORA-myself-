"""Independent byte/nibble fixtures for gr-lora_sdr commit 31243b0ac9cc... .

Uses the reference literal whitening/Hamming tables, stdlib CRC, and the
inverse permutation of the MATLAB interleaver. This is not a BER oracle.
Algorithm provenance: tapparelj/gr-lora_sdr (GPL-3.0), lib/{tables,header,
add_crc,hamming_enc,hamming_dec,interleaver,gray_demap}_impl sources.
"""
import binascii
import json
from pathlib import Path

WHITENING = bytes.fromhex(
    "ff fe fc f8 f0 e1 c2 85 0b 17 2f 5e bc 78 f1 e3 "
    "c6 8d 1a 34 68 d0 a0 40 80 01 02 04 08 11 23 47 "
    "8e 1c 38 71 e2 c4 89 12 25 4b 97 2e 5c b8 70 e0 "
    "c0 81 03 06 0c 19 32 64 c9 92 24 49 93 26 4d 9b "
    "37 6e dc b9 72 e4 c8 90 20 41 82 05 0a 15 2b 56 "
    "ad 5b b6 6d da b5 6b d6 ac 59 b2 65 cb 96 2c 58 "
    "b0 61 c3 87 0f 1f 3e 7d fb f6 ed db b7 6f de bd "
    "7a f5 eb d7 ae 5d ba 74 e8 d1 a2 44 88 10 21 43 "
    "86 0d 1b 36 6c d8 b1 63 c7 8f 1e 3c 79 f3 e7 ce "
    "9c 39 73 e6 cc 98 31 62 c5 8b 16 2d 5a b4 69 d2 "
    "a4 48 91 22 45 8a 14 29 52 a5 4a 95 2a 54 a9 53 "
    "a7 4e 9d 3b 77 ee dd bb 76 ec d9 b3 67 cf 9e 3d "
    "7b f7 ef df bf 7e fd fa f4 e9 d3 a6 4c 99 33 66 "
    "cd 9a 35 6a d4 a8 51 a3 46 8c 18 30 60 c1 83 07 "
    "0e 1d 3a 75 ea d5 aa 55 ab 57 af 5f be 7c f9 f2 "
    "e5 ca 94 28 50 a1 42 84 09 13 27 4f 9f 3f 7f")
HAM8 = [0, 23, 45, 58, 78, 89, 99, 116, 139, 156, 166, 177, 197, 210, 232, 255]
HAM5 = [0, 24, 40, 48, 72, 80, 96, 120, 136, 144, 160, 184, 192, 216, 232, 240]

def reverse_nibble(n):
    return int(f"{n:04b}"[::-1], 2)

def crc(payload):
    return binascii.crc_hqx(payload[:-2], 0) ^ (payload[-2] << 8) ^ payload[-1]

def header(length, cr):
    h = [length >> 4, length & 15, 2 * cr + 1]
    masks = [(15, 0, 0), (8, 14, 1), (4, 9, 10), (2, 5, 7), (1, 2, 15)]
    bits = [sum((a & b).bit_count() for a, b in zip(h, m)) & 1 for m in masks]
    return h + [bits[0], sum(bit << (3 - i) for i, bit in enumerate(bits[1:]))]

def gray_inverse(n):
    value = n
    while n:
        n >>= 1
        value ^= n
    return value

def hard_decode(word, cr):
    width = 4 + cr
    bits = [(word >> (width - 1 - i)) & 1 for i in range(width)]
    data = sum(bits[i] << i for i in range(4))
    if cr == 4 and word.bit_count() & 1:
        s = ((bits[0] ^ bits[1] ^ bits[2] ^ bits[4])
             + 2 * (bits[1] ^ bits[2] ^ bits[3] ^ bits[5])
             + 4 * (bits[0] ^ bits[1] ^ bits[3] ^ bits[6]))
        if s in (5, 7, 3, 6):
            data ^= 1 << (5, 7, 3, 6).index(s)
    return data

def encode(payload, sf, cr, ldro, explicit):
    whitened = bytes(a ^ b for a, b in zip(payload, WHITENING))
    nibs = header(len(payload), cr) if explicit else []
    nibs += [n for byte in whitened for n in (byte & 15, byte >> 4)]
    checksum = crc(payload)
    nibs += [(checksum >> (4 * i)) & 15 for i in range(4)]
    words, symbols, block_sizes, widths = [], [], [], []
    offset = 0
    while offset < len(nibs):
        first = offset == 0
        reduced = first or ldro
        rows = sf - (2 if reduced else 0)
        rate = 4 if first else cr
        width = 4 + rate
        taken = nibs[offset:offset + rows]
        lookup = HAM8 if rate == 4 else HAM5
        block = [lookup[reverse_nibble(n)] >> (8 - width) for n in taken]
        block += [0] * (rows - len(block))
        words += block
        inter = [0] * width
        for source, word in enumerate(block):
            for column in range(width):
                if word & (1 << (width - 1 - column)):
                    target = (column - source - 1) % rows
                    inter[column] |= 1 << (sf - 1 - target)
        for label in inter:
            if reduced:
                label |= (label.bit_count() & 1) << 1
            symbols.append((gray_inverse(label) + 1) % (1 << sf))
        block_sizes.append(rows)
        widths.append(width)
        offset += rows
    return dict(payload=list(payload), sf=sf, cr=cr, ldro=ldro, explicit=explicit,
                crc=checksum, nibbles=nibs, words=words, symbols=symbols,
                rows=block_sizes, widths=widths)

def main():
    fixtures = [encode(bytes((17 * i + length) & 255 for i in range(length)),
                       sf, cr, ldro, explicit)
                for length in (2, 3, 16, 32) for sf in (7, 12)
                for cr in (1, 4) for ldro in (False, True) for explicit in (False, True)]
    result = dict(commit="31243b0ac9cc8255f860dc85fc9594734856e03e",
                  whitening=list(WHITENING), ham8=HAM8, ham5=HAM5,
                  decode1=[hard_decode(w, 1) for w in range(32)],
                  decode4=[hard_decode(w, 4) for w in range(256)], fixtures=fixtures)
    # This generated test data is not simulation output and contains no error-rate pool.
    output = Path(__file__).with_name("reference_vectors.json")
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Reference fixtures: {len(fixtures)} frames, 288 decoder entries")

if __name__ == "__main__":
    main()
