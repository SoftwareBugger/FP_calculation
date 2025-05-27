# The script is used to generate binary pattern 
# Format:
# number1_number2_result_mode
# The number and result are in complement code

import numpy as np 
import random 
import math

def generate_mul_golden():
    golden_list = ""
    golden_list_dec = ""

    # case for int8
    for _ in range(10):
        a = random.randint(-127,128)
        b = random.randint(-127,128)
        expected = a*b
        a_bin = np.binary_repr(a,width=8).zfill(16)
        b_bin = np.binary_repr(b,width=8).zfill(16)
        expected_bin = np.binary_repr(expected,width=16)
        golden_list += "{}_{}_{}_0\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(int8) * {}(int8) = {}(int8)\n".format(a,b,expected)

    # underflow case for fp16
    for _ in range(5):
        a = random.uniform(-0.0001,0.0001)
        b = random.uniform(-0.0001,0.0001)
        expected = a*b
        a_bin =  bin(np.float16(a).view("H"))[2:].zfill(16)
        b_bin =  bin(np.float16(b).view("H"))[2:].zfill(16)
        expected_bin = bin(np.float16(expected).view("H"))[2:].zfill(16)
        
        golden_list += "{}_{}_{}_1\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(fp16) * {}(fp16) = {}(fp16)\n".format(a,b,expected) 

    # overflow case for fp16
    for _ in range(5):
        a = random.uniform(10000,10100)
        b = random.uniform(-10100,-10000)
        expected = a*b
        a_bin =  bin(np.float16(a).view("H"))[2:].zfill(16)
        b_bin =  bin(np.float16(b).view("H"))[2:].zfill(16)
        expected_bin = bin(np.float16(expected).view("H"))[2:].zfill(16)
        
        golden_list += "{}_{}_{}_1\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(fp16) * {}(fp16) = {}(fp16)\n".format(a,b,expected) 

    # normal case for fp16
    for _ in range(10):
        a = random.uniform(-1,1)
        b = random.uniform(-1,1)
        expected = a*b
        a_bin =  bin(np.float16(a).view("H"))[2:].zfill(16)
        b_bin =  bin(np.float16(b).view("H"))[2:].zfill(16)
        expected_bin = bin(np.float16(expected).view("H"))[2:].zfill(16)
        
        golden_list += "{}_{}_{}_1\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(fp16) * {}(fp16) = {}(fp16)\n".format(a,b,expected) 

    with open("mul_golden_pattern.txt",'w') as f:
        f.write(golden_list)
    with open("mul_golden_decimal.txt",'w') as f:
        f.write(golden_list_dec)

def generate_add_golden():
    golden_list = ""
    golden_list_dec = ""

    # case for int8
    for _ in range(10):
        a = random.randint(-127,128)
        b = random.randint(-127,128)
        expected = a+b
        a_bin = np.binary_repr(a,width=16).zfill(16)
        b_bin = np.binary_repr(b,width=16).zfill(16)
        expected_bin = np.binary_repr(expected,width=16)
        golden_list += "{}_{}_{}_0\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(int8) + {}(int8) = {}(int8)\n".format(a,b,expected)

    #case for fp16
    for _ in range(10):
        a = random.uniform(-1,1)
        b = random.uniform(-1,1)
        expected = a+b
        a_bin =  bin(np.float16(a).view("H"))[2:].zfill(16)
        b_bin =  bin(np.float16(b).view("H"))[2:].zfill(16)
        expected_bin = bin(np.float16(expected).view("H"))[2:].zfill(16)
        golden_list += "{}_{}_{}_1\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(fp16) + {}(fp16) = {}(fp16)\n".format(a,b,expected) 

    with open("add_golden_pattern.txt",'w') as f:
        f.write(golden_list)
    with open("add_golden_decimal.txt",'w') as f:
        f.write(golden_list_dec)

def generate_fp16_mac_golden():

    golden_list = ""
    golden_list_dec = ""

    for _ in range(10):
        a = random.uniform(-1,1)
        b = random.uniform(-1,1)
        c = random.uniform(-1,1)
        expected = a*b + c
        a_bin =  bin(np.float16(a).view("H"))[2:].zfill(16)
        b_bin =  bin(np.float16(b).view("H"))[2:].zfill(16)
        c_bin =  bin(np.float16(c).view("H"))[2:].zfill(16)
        expected_bin = bin(np.float16(expected).view("H"))[2:].zfill(16)
        golden_list += "{}_{}_{}_{}_1\n".format(a_bin,b_bin,c_bin,expected_bin)
        golden_list_dec += "{}(fp16) * {}(fp16) + {}(fp16) = {}(fp16)\n".format(a,b,c,expected)        
       
    with open("mac_fp16_golden_pattern.txt",'w') as f:
        f.write(golden_list)
    with open("mac_fp16_golden_decimal.txt",'w') as f:
        f.write(golden_list_dec)

def generate_fp16_add_golden():

    golden_list = ""
    golden_list_dec = ""

    #case for fp16
    for _ in range(1000):
        a = random.uniform(-1,1)
        b = random.uniform(-1,1)
        a_bin =  bin(np.float16(a).view("H"))[2:].zfill(16)
        b_bin =  bin(np.float16(b).view("H"))[2:].zfill(16)
        a16       = np.float16(a)                # round A → half
        b16       = np.float16(b)                # round B → half
        sum32     = a16 + b16                    # numpy does this in float32 internally
        expected  = np.float16(sum32)            # final round → half
        expected_bin = bin(expected.view("H"))[2:].zfill(16)
        golden_list += "{}_{}_{}_1\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(fp16) + {}(fp16) = {}(fp16)\n".format(a,b,expected)        
       
    with open("add_fp16_golden_pattern.txt",'w') as f:
        f.write(golden_list)
    with open("add_fp16_golden_decimal.txt",'w') as f:
        f.write(golden_list_dec)

def generate_fp16_mult_golden():

    golden_list = ""
    golden_list_dec = ""

    #case for fp16
    for _ in range(1000):
        a = random.uniform(-1,1)
        b = random.uniform(-1,1)
        a_bin =  bin(np.float16(a).view("H"))[2:].zfill(16)
        b_bin =  bin(np.float16(b).view("H"))[2:].zfill(16)
        a16       = np.float16(a)                # round A → half
        b16       = np.float16(b)                # round B → half
        sum32     = a16 * b16                    # numpy does this in float32 internally
        expected  = np.float16(sum32)            # final round → half
        expected_bin = bin(expected.view("H"))[2:].zfill(16)
        golden_list += "{}_{}_{}_1\n".format(a_bin,b_bin,expected_bin)
        golden_list_dec += "{}(fp16) + {}(fp16) = {}(fp16)\n".format(a,b,expected)        
       
    with open("mult_fp16_golden_pattern.txt",'w') as f:
        f.write(golden_list)
    with open("mult_fp16_golden_decimal.txt",'w') as f:
        f.write(golden_list_dec)


def quantize_to_fp8(value, e_bits, m_bits):
    """Quantize a Python float to an e_bits/m_bits floating-point format (round to nearest even)."""
    # Handle NaN
    if math.isnan(value):
        sign = 0
        exp_bits = (1 << e_bits) - 1
        frac_bits = 1 << (m_bits - 1)  # QNaN
        return (sign << (e_bits + m_bits)) | (exp_bits << m_bits) | frac_bits
    # Handle Inf
    if math.isinf(value):
        sign = 0 if value > 0 else 1
        exp_bits = (1 << e_bits) - 1
        frac_bits = 0
        return (sign << (e_bits + m_bits)) | (exp_bits << m_bits) | frac_bits
    
    # Decompose
    sign = 0
    if value < 0:
        sign = 1
    val = abs(value)
    # Handle zero
    if val == 0.0:
        return 0
    
    bias = (1 << (e_bits - 1)) - 1
    m, exp = math.frexp(val)  # val = m * 2**exp, 0.5 <= m < 1
    # Convert to [1,2) range
    m *= 2
    exp -= 1
    
    exp_bits = exp + bias
    # Overflow -> Inf
    if exp_bits >= (1 << e_bits) - 1:
        exp_bits = (1 << e_bits) - 1
        frac_bits = 0
    # Subnormal
    elif exp_bits <= 0:
        exp_bits = 0
        # scale for subnormal: val / 2^(1-bias-m_bits)
        scale = val / (2.0 ** (1 - bias - m_bits))
        # Round to nearest even
        frac_floor = math.floor(scale)
        rem = scale - frac_floor
        if rem > 0.5 or (rem == 0.5 and (frac_floor % 2 == 1)):
            frac_floor += 1
        frac_bits = max(0, min(frac_floor, (1 << m_bits) - 1))
    # Normal
    else:
        # Fraction part
        frac = (m - 1.0) * (1 << m_bits)
        floor_frac = math.floor(frac)
        rem = frac - floor_frac
        if rem > 0.5 or (rem == 0.5 and (floor_frac % 2 == 1)):
            floor_frac += 1
            # Handle carry out
            if floor_frac == (1 << m_bits):
                floor_frac = 0
                exp_bits += 1
                if exp_bits >= (1 << e_bits) - 1:
                    exp_bits = (1 << e_bits) - 1
        frac_bits = int(floor_frac)
    
    return (sign << (e_bits + m_bits)) | (exp_bits << m_bits) | frac_bits

def generate_fp8_add_golden(e_bits, m_bits, count=1000):
    """Generate golden patterns for FP8 addition with given exponent and mantissa bits."""
    bias = (1 << (e_bits - 1)) - 1
    pattern_file = f"add_fp8_E{e_bits}M{m_bits}_pattern.txt"
    decimal_file = f"add_fp8_E{e_bits}M{m_bits}_decimal.txt"
    
    with open(pattern_file, 'w') as pf, open(decimal_file, 'w') as df:
        for _ in range(count):
            a = random.uniform(-8.0, 8.0)
            b = random.uniform(-8.0, 8.0)
            a_q = quantize_to_fp8(a, e_bits, m_bits)
            b_q = quantize_to_fp8(b, e_bits, m_bits)
            # Perform addition in float32 then quantize back
            expected = quantize_to_fp8(math.ldexp(math.ldexp(a_q & ((1<<(e_bits+m_bits))-1), -m_bits), 1) + 
                                       math.ldexp(math.ldexp(b_q & ((1<<(e_bits+m_bits))-1), -m_bits), 1),
                                       e_bits, m_bits)
            # Format binaries
            a_bin = format(a_q, f"0{e_bits+m_bits+1}b")
            b_bin = format(b_q, f"0{e_bits+m_bits+1}b")
            exp_bin = format(expected, f"0{e_bits+m_bits+1}b")
            pf.write(f"{a_bin}_{b_bin}_{exp_bin}_1\n")
            df.write(f"{a} -> {a_bin}, {b} -> {b_bin}, sum = {exp_bin} ({expected})\n")
    print(f"Generated {pattern_file} and {decimal_file} for E{e_bits}M{m_bits}")

def quantize_to_fu(value, e_bits, m_bits):
    """Quantize a Python float to an e_bits/m_bits floating-point format (round to nearest even)."""
    # Handle NaN
    if math.isnan(value):
        sign = 0
        exp_bits = (1 << e_bits) - 1
        frac_bits = 1 << (m_bits - 1)  # QNaN
        return (sign << (e_bits + m_bits)) | (exp_bits << m_bits) | frac_bits
    # Handle Inf
    if math.isinf(value):
        sign = 0 if value > 0 else 1
        exp_bits = (1 << e_bits) - 1
        frac_bits = 0
        return (sign << (e_bits + m_bits)) | (exp_bits << m_bits) | frac_bits
    
    # Decompose sign
    sign = 0
    if value < 0:
        sign = 1
    val = abs(value)
    # Handle zero
    if val == 0.0:
        return 0
    
    bias = (1 << (e_bits - 1)) - 1
    m, exp = math.frexp(val)  # val = m * 2**exp, 0.5 <= m < 1
    # Convert to [1,2) range for normal
    m *= 2.0
    exp -= 1
    
    exp_bits = exp + bias
    # Overflow -> Inf
    if exp_bits >= (1 << e_bits) - 1:
        exp_bits = (1 << e_bits) - 1
        frac_bits = 0
    # Subnormal
    elif exp_bits <= 0:
        exp_bits = 0
        # scale for subnormal: val / 2^(1-bias-m_bits)
        scale = val / (2.0 ** (1 - bias - m_bits))
        floor_val = math.floor(scale)
        rem = scale - floor_val
        if rem > 0.5 or (rem == 0.5 and (floor_val % 2 == 1)):
            floor_val += 1
        frac_bits = max(0, min(int(floor_val), (1 << m_bits) - 1))
    # Normal
    else:
        frac = (m - 1.0) * (1 << m_bits)
        floor_frac = math.floor(frac)
        rem = frac - floor_frac
        if rem > 0.5 or (rem == 0.5 and (floor_frac % 2 == 1)):
            floor_frac += 1
            # Handle carry out
            if floor_frac == (1 << m_bits):
                floor_frac = 0
                exp_bits += 1
                if exp_bits >= (1 << e_bits) - 1:
                    exp_bits = (1 << e_bits) - 1
        frac_bits = int(floor_frac)
    
    return (sign << (e_bits + m_bits)) | (exp_bits << m_bits) | frac_bits

def dequantize_fu(bits, e_bits, m_bits):
    """Convert quantized bits back to Python float."""
    sign = (bits >> (e_bits + m_bits)) & 1
    exp_bits = (bits >> m_bits) & ((1 << e_bits) - 1)
    frac_bits = bits & ((1 << m_bits) - 1)
    
    bias = (1 << (e_bits - 1)) - 1
    if exp_bits == 0:
        # Zero or subnormal
        if frac_bits == 0:
            return -0.0 if sign else 0.0
        mant = frac_bits / (1 << m_bits)
        exp = 1 - bias
    elif exp_bits == (1 << e_bits) - 1:
        # Inf or NaN
        if frac_bits == 0:
            return float('-inf') if sign else float('inf')
        return float('nan')
    else:
        mant = 1 + frac_bits / (1 << m_bits)
        exp = exp_bits - bias
    
    value = math.ldexp(mant, exp)
    return -value if sign else value

def generate_vectorized_fp8_add_golden(e_bits, m_bits, count=1000):
    """Generate golden patterns for vectorized (2-lane) FP8 addition."""
    pattern_file = f"add_fp8x2_E{e_bits}M{m_bits}_pattern.txt"
    decimal_file = f"add_fp8x2_E{e_bits}M{m_bits}_decimal.txt"
    width = e_bits + m_bits + 1
    
    with open(pattern_file, 'w') as pf, open(decimal_file, 'w') as df:
        for _ in range(count):
            # generate two lane inputs
            a0 = random.uniform(-8.0, 16.0)
            b0 = random.uniform(-8.0, 16.0)
            a1 = random.uniform(-8.0, 16.0)
            b1 = random.uniform(-8.0, 16.0)
            
            # quantize to FP8 bits
            a0_q = quantize_to_fu(a0, e_bits, m_bits)
            b0_q = quantize_to_fu(b0, e_bits, m_bits)
            a1_q = quantize_to_fu(a1, e_bits, m_bits)
            b1_q = quantize_to_fu(b1, e_bits, m_bits)
            
            # perform Python float add then quantize output
            res0 = quantize_to_fu(dequantize_fu(a0_q, e_bits, m_bits) + dequantize_fu(b0_q, e_bits, m_bits),
                                   e_bits, m_bits)
            res1 = quantize_to_fu(dequantize_fu(a1_q, e_bits, m_bits) + dequantize_fu(b1_q, e_bits, m_bits),
                                   e_bits, m_bits)
            
            # pack into 16-bit vector words (low lane = bits[7:0], high lane = bits[15:8])
            a_vec = (a1_q << 8) | (a0_q & ((1<<width)-1))
            b_vec = (b1_q << 8) | (b0_q & ((1<<width)-1))
            r_vec = (res1 << 8) | (res0 & ((1<<width)-1))
            
            # format binary strings
            a_bin = format(a_vec, f"0{2*width}b")
            b_bin = format(b_vec, f"0{2*width}b")
            r_bin = format(r_vec, f"0{2*width}b")
            
            pf.write(f"{a_bin}_{b_bin}_{r_bin}_1\n")
            df.write(f"A0={a0:.6f} -> {a0_q:#0{width+2}b}, B0={b0:.6f} -> {b0_q:#0{width+2}b}, "
                     f"R0={res0:#0{width+2}b}; "
                     f"A1={a1:.6f} -> {a1_q:#0{width+2}b}, B1={b1:.6f} -> {b1_q:#0{width+2}b}, "
                     f"R1={res1:#0{width+2}b}\n")
    print(f"Generated {pattern_file} and {decimal_file}")

def generate_vectorized_fp8_mul_golden(e_bits, m_bits, count=1000):
    """Generate golden patterns for vectorized (2-lane) FP8 multiplication."""
    pattern_file = f"mul_fp8x2_E{e_bits}M{m_bits}_pattern.txt"
    decimal_file = f"mul_fp8x2_E{e_bits}M{m_bits}_decimal.txt"
    width = e_bits + m_bits + 1

    with open(pattern_file, 'w') as pf, open(decimal_file, 'w') as df:
        for _ in range(count):
            # generate two lane inputs
            a0 = random.uniform(-16.0, 16.0)
            b0 = random.uniform(-16.0, 16.0)
            a1 = random.uniform(-16.0, 16.0)
            b1 = random.uniform(-16.0, 16.0)

            # quantize to FP8 bits
            a0_q = quantize_to_fu(a0, e_bits, m_bits)
            b0_q = quantize_to_fu(b0, e_bits, m_bits)
            a1_q = quantize_to_fu(a1, e_bits, m_bits)
            b1_q = quantize_to_fu(b1, e_bits, m_bits)

            # perform Python float multiply then quantize back
            res0 = quantize_to_fu(
                dequantize_fu(a0_q, e_bits, m_bits) * dequantize_fu(b0_q, e_bits, m_bits),
                e_bits, m_bits
            )
            res1 = quantize_to_fu(
                dequantize_fu(a1_q, e_bits, m_bits) * dequantize_fu(b1_q, e_bits, m_bits),
                e_bits, m_bits
            )

            # pack into 16-bit vector words (hi:a1,lo:a0)
            a_vec = (a1_q << 8) | (a0_q & ((1<<width)-1))
            b_vec = (b1_q << 8) | (b0_q & ((1<<width)-1))
            r_vec = (res1 << 8) | (res0 & ((1<<width)-1))

            a_bin = format(a_vec, f"0{2*width}b")
            b_bin = format(b_vec, f"0{2*width}b")
            r_bin = format(r_vec, f"0{2*width}b")

            pf.write(f"{a_bin}_{b_bin}_{r_bin}_1\n")
            df.write(
                f"A0={a0:.6f}->{a0_q:#0{width+2}b}, "
                f"B0={b0:.6f}->{b0_q:#0{width+2}b}, R0={res0:#0{width+2}b}; "
                f"A1={a1:.6f}->{a1_q:#0{width+2}b}, "
                f"B1={b1:.6f}->{b1_q:#0{width+2}b}, R1={res1:#0{width+2}b}\n"
            )
    print(f"Generated {pattern_file} and {decimal_file} for E{e_bits}M{m_bits}")

def pack_vec2(a_bits: int, b_bits: int, width: int) -> int:
    """Pack two lane‑width patterns into a 2×width‑bit word."""
    return (a_bits << width) | b_bits

def write_pattern_decimal(
    pf, df,
    a_vec: int, b_vec: int, r_vec: int,
    a0_bits:int, b0_bits:int, r0_bits:int,
    a1_bits:int, b1_bits:int, r1_bits:int,
    e_bits:int, m_bits:int
):
    width = e_bits + m_bits + 1
    fmt = f"0{2*width}b"
    pf.write(f"{format(a_vec,fmt)}_{format(b_vec,fmt)}_{format(r_vec,fmt)}_1\n")
    df.write(
        f"A0=0b{a0_bits:0{width}b}({dequantize_fu(a0_bits,e_bits,m_bits):.6g}) "
        f"* B0=0b{b0_bits:0{width}b}({dequantize_fu(b0_bits,e_bits,m_bits):.6g}) "
        f"= R0=0b{r0_bits:0{width}b}({dequantize_fu(r0_bits,e_bits,m_bits):.6g}); "
        f"A1=0b{a1_bits:0{width}b}({dequantize_fu(a1_bits,e_bits,m_bits):.6g}) "
        f"* B1=0b{b1_bits:0{width}b}({dequantize_fu(b1_bits,e_bits,m_bits):.6g}) "
        f"= R1=0b{r1_bits:0{width}b}({dequantize_fu(r1_bits,e_bits,m_bits):.6g})\n"
    )

def generate_fp8x2_zero_cases(e_bits, m_bits):
    """Edge cases where one or both lanes are zero ±0."""
    width = e_bits + m_bits + 1
    pattern_file = f"fp8x2_zero_E{e_bits}M{m_bits}_pattern.txt"
    decimal_file = f"fp8x2_zero_E{e_bits}M{m_bits}_decimal.txt"

    zero_p = quantize_to_fu(0.0, e_bits, m_bits)
    negz_p = quantize_to_fu(-0.0, e_bits, m_bits)

    cases = [
        (zero_p, zero_p),
        (zero_p, negz_p),
        (negz_p, zero_p),
        (negz_p, negz_p),
    ]

    with open(pattern_file,'w') as pf, open(decimal_file,'w') as df:
        for a0,b0 in cases:
            for a1,b1 in cases:
                r0 = quantize_to_fu(
                    dequantize_fu(a0,e_bits,m_bits) * dequantize_fu(b0,e_bits,m_bits),
                    e_bits,m_bits
                )
                r1 = quantize_to_fu(
                    dequantize_fu(a1,e_bits,m_bits) * dequantize_fu(b1,e_bits,m_bits),
                    e_bits,m_bits
                )
                a_vec = pack_vec2(a1,a0,width)
                b_vec = pack_vec2(b1,b0,width)
                r_vec = pack_vec2(r1,r0,width)
                write_pattern_decimal(pf, df,
                    a_vec, b_vec, r_vec,
                    a0,b0,r0, a1,b1,r1,
                    e_bits,m_bits
                )
    print(f"Written zero cases → {pattern_file}, {decimal_file}")


def generate_fp8x2_subnormal_cases(e_bits, m_bits):
    """Edge cases for subnormals: exp_field=0, mantissa≠0."""
    width = e_bits + m_bits + 1
    pattern_file = f"fp8x2_denorm_E{e_bits}M{m_bits}_pattern.txt"
    decimal_file = f"fp8x2_denorm_E{e_bits}M{m_bits}_decimal.txt"

    # all nonzero mantissas with exp=0 are subnormals
    denorms = [ (1<< (m_bits - 1)) - 1 ]  # just pick the smallest positive mantissa=1
    # you could expand to all [1..(1<<m_bits)-1] if you like

    sub_list = []
    for frac in denorms:
        # positive, then negative
        bits_p = (0 << (e_bits + m_bits)) | frac
        bits_n = bits_p | (1 << (e_bits + m_bits))
        sub_list.extend([bits_p, bits_n])

    with open(pattern_file,'w') as pf, open(decimal_file,'w') as df:
        for a0 in sub_list:
            for b0 in sub_list:
                # multiply two subnormals
                r0 = quantize_to_fu(
                    dequantize_fu(a0,e_bits,m_bits)*dequantize_fu(b0,e_bits,m_bits),
                    e_bits,m_bits
                )
                # mix with a normal lane
                a1 = quantize_to_fu(1.0, e_bits, m_bits)
                b1 = quantize_to_fu(2.0, e_bits, m_bits)
                r1 = quantize_to_fu(
                    dequantize_fu(a1,e_bits,m_bits)*dequantize_fu(b1,e_bits,m_bits),
                    e_bits,m_bits
                )

                a_vec = pack_vec2(a1,a0,width)
                b_vec = pack_vec2(b1,b0,width)
                r_vec = pack_vec2(r1,r0,width)
                write_pattern_decimal(pf, df, a_vec, b_vec, r_vec,
                    a0,b0,r0, a1,b1,r1, e_bits,m_bits
                )
    print(f"Written subnormal cases → {pattern_file}, {decimal_file}")


def generate_fp8x2_overflow_inf_nan_cases(e_bits, m_bits):
    """Edge cases for overflow → Inf, and NaN handling."""
    width = e_bits + m_bits + 1
    pattern_file = f"fp8x2_infnan_E{e_bits}M{m_bits}_pattern.txt"
    decimal_file = f"fp8x2_infnan_E{e_bits}M{m_bits}_decimal.txt"

    maxf = (1<<e_bits) - 2  # exp=all1-1
    max_frac = (1<<m_bits) - 1
    inf_bits = ((0)<< (e_bits+m_bits)) | (((1<<e_bits)-1)<<m_bits) | 0
    nan_bits = ((0)<< (e_bits+m_bits)) | (((1<<e_bits)-1)<<m_bits) | 1

    normals = [
        # largest finite positive and negative
        ((0<<(e_bits+m_bits)) | (maxf<<m_bits) | max_frac),
        (1<<(e_bits+m_bits)) | (maxf<<m_bits) | max_frac
    ]
    specials = [inf_bits, nan_bits]

    with open(pattern_file,'w') as pf, open(decimal_file,'w') as df:
        # overflow → expect ±Inf
        for a0 in normals:
            for b0 in normals:
                r0 = inf_bits  # overflow
                # lane1 mix: normal * 1.0
                a1 = a0
                b1 = quantize_to_fu(1.0, e_bits, m_bits)
                r1 = a1  # unchanged
                a_vec = pack_vec2(a1,a0,width)
                b_vec = pack_vec2(b1,b0,width)
                r_vec = pack_vec2(r1,r0,width)
                write_pattern_decimal(pf, df, a_vec, b_vec, r_vec,
                    a0,b0,r0, a1,b1,r1, e_bits,m_bits
                )
        # NaN propagation
        for s in specials:
            # NaN * anything → NaN
            a0 = s; b0 = quantize_to_fu(1.0,e_bits,m_bits)
            r0 = nan_bits
            a1 = quantize_to_fu(2.0,e_bits,m_bits); b1 = s; r1 = nan_bits
            a_vec = pack_vec2(a1,a0,width)
            b_vec = pack_vec2(b1,b0,width)
            r_vec = pack_vec2(r1,r0,width)
            write_pattern_decimal(pf, df, a_vec, b_vec, r_vec,
                a0,b0,r0, a1,b1,r1, e_bits,m_bits
            )
    print(f"Written Inf/NaN cases → {pattern_file}, {decimal_file}")

if __name__ == "__main__":
    generate_mul_golden()
    generate_add_golden()
    generate_fp16_mac_golden()
    generate_fp16_add_golden()
    generate_fp16_mult_golden()
    # Example usage:
    # Generate patterns for both E4M3 and E5M2
    generate_vectorized_fp8_add_golden(4, 3)
    generate_vectorized_fp8_add_golden(5, 2)
    generate_vectorized_fp8_mul_golden(4, 3)
    generate_vectorized_fp8_mul_golden(5, 2)
    # Generate zero cases
    generate_fp8x2_zero_cases(4, 3)
    generate_fp8x2_zero_cases(5, 2)
    # Generate subnormal cases
    generate_fp8x2_subnormal_cases(4, 3)
    generate_fp8x2_subnormal_cases(5, 2)
    # Generate overflow/inf/nan cases
    generate_fp8x2_overflow_inf_nan_cases(4, 3)
    generate_fp8x2_overflow_inf_nan_cases(5, 2)



    



    

    


    




