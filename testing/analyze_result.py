#!/usr/bin/env python3
import argparse
import math
import re
import sys

def dequantize_fp(bits: str, e_bits: int, m_bits: int) -> float:
    """
    Convert an IEEE-style FP bitstring to a Python float.
    bits: binary string of length 1+e_bits+m_bits
    """
    if len(bits) != 1 + e_bits + m_bits:
        raise ValueError(f"Bitstring length {len(bits)} does not match expected {1+e_bits+m_bits}")
    b = int(bits, 2)
    sign = (b >> (e_bits + m_bits)) & 0x1
    exp_field = (b >> m_bits) & ((1 << e_bits) - 1)
    frac_field = b & ((1 << m_bits) - 1)
    bias = (1 << (e_bits - 1)) - 1

    if exp_field == 0:
        # Zero or subnormal
        if frac_field == 0:
            return -0.0 if sign else 0.0
        # subnormal
        mant = frac_field / (1 << m_bits)
        exp = 1 - bias
    elif exp_field == (1 << e_bits) - 1:
        # Inf or NaN
        if frac_field == 0:
            return float('-inf') if sign else float('inf')
        return float('nan')
    else:
        mant = 1 + frac_field / (1 << m_bits)
        exp = exp_field - bias

    val = math.ldexp(mant, exp)
    return -val if sign else val

def ulp_spacing(x: float, m_bits: int) -> float:
    """
    Compute the ULP spacing for a value x given m_bits mantissa bits.
    Uses the unbiased exponent from math.frexp.
    """
    if x == 0.0 or not math.isfinite(x):
        # spacing of smallest normal/subnormal
        return 2 ** (-m_bits)
    mant, exp = math.frexp(abs(x))   # x = mant * 2**exp, mant in [0.5,1)
    # print(f"frexp: mant={mant}, exp={exp}")
    true_exp = exp - 1              # unbiased exponent for [1.0,2.0) form
    return 2 ** (true_exp - m_bits)


def extract_patterns(line: str, width: int):
    """
    Extract the first two binary strings of length `width` from the line.
    Returns (expected_bits, actual_bits) or (None, None) if not found.
    """
    pats = re.findall(rf'[01]{{{width}}}', line)
    if len(pats) >= 2:
        return pats[0], pats[1]
    return None, None

def analyze_file(path: str, mode: str, e_bits: int, m_bits: int):
    # Determine the total width to extract
    if mode == 'fp16':
        width = 1 + 5 + 10
    else:  # 'fp8x2'
        fp8_width = 1 + e_bits + m_bits
        width = fp8_width * 2

    total = 0
    sum_abs_err = sum_ulp_err = 0.0
    max_abs_err = max_ulp_err = 0.0
    max_percent_err = 0.0
    average_percent_err = 0.0
    worst_percent_expected = ""
    worst_percent_actual = ""
    worst_ULP_expected = ""
    worst_ULP_actual = ""
    worse_abs_expected = ""
    worse_abs_actual = ""

    with open(path, 'r') as f:
        for lineno, line in enumerate(f, start=1):
            exp_bits, act_bits = extract_patterns(line, width)
            if exp_bits is None:
                # Skip lines without valid patterns
                continue

            pairs = []
            if mode == 'fp16':
                pairs.append((exp_bits, act_bits, 5, 10))
            else:
                fp8_width = width // 2
                high_exp, low_exp = exp_bits[:fp8_width], exp_bits[fp8_width:]
                high_act, low_act = act_bits[:fp8_width], act_bits[fp8_width:]
                pairs.append((high_exp, high_act, e_bits, m_bits))
                pairs.append((low_exp,  low_act,  e_bits, m_bits))

            for ebits, abits, EB, MB in pairs:
                expected = dequantize_fp(ebits, EB, MB)
                actual   = dequantize_fp(abits, EB, MB)
                if not math.isfinite(expected):
                    continue

                abs_err = abs(actual - expected)
                spacing = ulp_spacing(expected, MB)
                ulp_err = abs_err / spacing if spacing > 0 else float('inf')
                percent_err = abs_err / abs(expected) if expected != 0 else 0.0
                average_percent_err += percent_err
                if percent_err*100 > max_percent_err:
                    worst_percent_actual = actual#abits
                    worst_percent_expected = expected#ebits
                max_percent_err = max(max_percent_err, percent_err*100.0)


                total += 1
                sum_abs_err += abs_err
                sum_ulp_err += ulp_err
                if abs_err > max_abs_err:
                    worse_abs_expected = f"{ebits} ({expected:.6e})"
                    worse_abs_actual = f"{abits} ({actual:.6e})"
                max_abs_err = max(max_abs_err, abs_err)
                if ulp_err > max_ulp_err:
                    worst_ULP_actual = f"{abits} ({actual:.6e})"
                    worst_ULP_expected = f"{ebits} ({expected:.6e})"
                max_ulp_err = max(max_ulp_err, ulp_err)

    if total == 0:
        print("No valid data found in file.", file=sys.stderr)
        return

    avg_abs_err = sum_abs_err / total
    avg_ulp_err = sum_ulp_err / total
    avg_percent_err = average_percent_err / total
    avg_percent_err = avg_percent_err * 100.0

    print(f"Mode: {mode}, e_bits={e_bits}, m_bits={m_bits}")
    print(f"Total values compared: {total}")
    print(f"Average absolute error: {avg_abs_err:.6e}")
    print(f"Maximum absolute error: {max_abs_err:.6e}")
    print(f"Average ULP error: {avg_ulp_err:.4f}")
    print(f"Maximum ULP error: {max_ulp_err:.4f}")
    print(f"Average percent error: {avg_percent_err:.4f}%")
    print(f"Maximum percent error: {max_percent_err:.4f}%")
    print(f"Worst percent error expected: {worst_percent_expected}")
    print(f"Worst percent error actual: {worst_percent_actual}")
    print(f"Worst ULP error expected: {worst_ULP_expected}")
    print(f"Worst ULP error actual: {worst_ULP_actual}")
    print(f"Worst absolute error expected: {worse_abs_expected}")
    print(f"Worst absolute error actual: {worse_abs_actual}")

def main():
    parser = argparse.ArgumentParser(description="FP error analysis (abs + ULP)")
    parser.add_argument("file", help="Path to results file")
    parser.add_argument("--mode", choices=["fp16", "fp8x2"], default="fp16",
                        help="Operation mode: fp16 or fp8x2")
    parser.add_argument("--e_bits", type=int, default=5,
                        help="Exponent bits for FP8 (only for fp8x2)")
    parser.add_argument("--m_bits", type=int, default=2,
                        help="Mantissa bits for FP8 (only for fp8x2)")
    args = parser.parse_args()

    analyze_file(args.file, args.mode, args.e_bits, args.m_bits)

if __name__ == "__main__":
    main()



