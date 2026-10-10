"""Literal reference LUT/loop fixtures, GPL-3.0 gr-lora_sdr 31243b0ac9cc...

Prints JSON; does not write files or generate simulation/target outcomes.
Log I0 uses its power series, independently of MATLAB's scaled besseli.
"""
import json
import math
import random

HAM8 = [0, 23, 45, 58, 78, 89, 99, 116, 139, 156, 166, 177, 197, 210, 232, 255]
HAM5 = [0, 24, 40, 48, 72, 80, 96, 120, 136, 144, 160, 184, 192, 216, 232, 240]


def soft_word(llr, cr):
    lookup = HAM5 if cr == 1 else HAM8
    width = cr + 4
    scores = []
    for code in lookup:
        word = code >> (8 - width)
        score = 0.0
        for j, confidence in enumerate(llr):
            bit = bool(word & (1 << (width - 1 - j)))
            score += abs(confidence) if ((bit and confidence > 0) or
                                        (not bit and confidence < 0)) else -abs(confidence)
        scores.append(score)
    chosen = max(range(16), key=scores.__getitem__)
    high = HAM8[chosen] >> 4
    return int(f"{high:04b}"[::-1], 2)


def log_i0(x):
    term = total = 1.0
    for k in range(1, 5000):
        term *= x * x / (4 * k * k)
        total += term
        if term <= total * 1e-16:
            return math.log(total)
    raise ArithmeticError("I0 series did not converge")


def bit_llrs(power, reduced):
    n = len(power)
    rows = n.bit_length() - 1 - 2 * reduced
    peak = max(range(n), key=power.__getitem__)
    adjacent = [abs(i - peak) % (n - 1) < 2 for i in range(n)]
    ps = sum(e for e, selected in zip(power, adjacent) if selected) / n
    pn = sum(e for e, selected in zip(power, adjacent) if not selected) / (n - 3)
    # Upstream line 189: energy *= N AFTER Ps/Pn estimation, before Bessel.
    normalized = [e * n for e in power]
    if max(power) == 0:
        likelihood = [0.0] * n
        clipped = False
    else:
        clipped = pn == 0 or math.sqrt(ps) / pn * math.sqrt(max(normalized)) >= 713
        likelihood = normalized if clipped else [log_i0(math.sqrt(ps) / pn * math.sqrt(e)) for e in normalized]
    labels = [((i - 1) % n) // (4 if reduced else 1) for i in range(n)]
    labels = [label ^ (label >> 1) for label in labels]
    result = []
    for bit in range(rows - 1, -1, -1):
        one = max((e for e, label in zip(likelihood, labels) if label & (1 << bit)), default=0)
        zero = max((e for e, label in zip(likelihood, labels) if not label & (1 << bit)), default=0)
        result.append(one - zero)
    return result, clipped


def main():
    stream = random.Random(31243)
    hamming = []
    for cr in (1, 4):
        width = cr + 4
        candidates = [[1.0 if word & (1 << (width - 1 - j)) else -1.0
                       for j in range(width)] for word in range(1 << width)]
        candidates += [[stream.randint(-24, 24) / 4 for _ in range(width)] for _ in range(64)]
        candidates += [[0.0] * width]
        for llr in candidates:
            hamming.append(dict(cr=cr, llr=llr, nibble=soft_word(llr, cr)))
    powers = []
    for reduced in (False, True):
        for peak in (0, 1, 63, 127):
            power = [((37 * i + 19) % 101 + 17) / 32 for i in range(128)]
            power[peak] += 731
            llr, clipped = bit_llrs(power, reduced)
            powers.append(dict(power=power, reduced=reduced, llr=llr, clipped=clipped))
        for scale in (0, 1e12):
            power = [0.0] * 128
            power[63] = scale
            llr, clipped = bit_llrs(power, reduced)
            powers.append(dict(power=power, reduced=reduced, llr=llr, clipped=clipped))
    print(json.dumps(dict(commit="31243b0ac9cc8255f860dc85fc9594734856e03e",
                         hamming=hamming, powers=powers), separators=(",", ":")))


if __name__ == "__main__":
    main()
