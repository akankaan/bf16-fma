# Python reference model for the validation of the Bfloat16 FMU (Fused Multiply Unit)

# Author: Kaan Akan
# Date  : July 20, 2026

from fractions import Fraction

def decode_bits(u: int):
    # u: bf16 as a 16-bit unsigned int with the {sign, exp, mantissa} format
    sign_bit        = (u >> 15) & (0x1)  #(0b1)
    exponent_bits   = (u >> 7)  & (0xFF) #(0b1111_1111)
    mantissa_bits   = (u)       & (0x7F) #(0b0111_1111)

    return sign_bit, exponent_bits, mantissa_bits

def to_exact(u: int):
    # Generates the exact value of bf16-encoded u with the implementation rules

    sign_bit, exponent_bits, mantissa_bits = decode_bits(u)

    assert exponent_bits != 0xFF, "inf and NaN are handled prior to exact conversion"

    if (exponent_bits == 0x0):
        # Value is zero or subnormal which are flushed to zero: DAZ
        return Fraction(0)

    # +128 comes from the implicit 1 of significand
    exact_value = (Fraction(128 + mantissa_bits, 128) * 
                   Fraction(2) ** (exponent_bits - 127))

    # Apply sign
    if (sign_bit):
        exact_value = -exact_value

    return(exact_value)

def mul_exact(a: int, b: int):
    # Returns exact value of the multiplication two bf-16 encoded inputs

    return to_exact(a) * to_exact(b)

def add_exact(intermediate: Fraction, c: int):
    # Returns exact value of the addition of the unrounded intermediate,
    # hence the Fraction input, with the second bf-16 encoded input

    return intermediate + to_exact(c)

# Smoke testing inline asserts only fire in direct execution
if (__name__ == "__main__"):

    assert decode_bits(0b1111_1111_1111_1111) == (0b1, 0b1111_1111, 0b1111_111)
    assert decode_bits(0b0111_1111_1111_1111) == (0b0, 0b1111_1111, 0b1111_111)
    assert decode_bits(0b0101_0011_1101_1011) == (0b0, 0b1010_0111, 0b1011_011)
    assert decode_bits(0b1010_1100_0010_0100) == (0b1, 0b0101_1000, 0b0100_100)

    assert to_exact(0x3F80) == 1                           # 1.0
    assert to_exact(0xBF80) == -1                          # -1.0
    assert to_exact(0xC000) == -2                          # -2.0
    assert to_exact(0x3FC0) == Fraction(3, 2)              # 1.5
    assert to_exact(0x3F00) == Fraction(1, 2)              # 0.5
    assert to_exact(0x0080) == Fraction(2) ** -126         # smallest normal
    assert to_exact(0x0000) == 0                           # +0
    assert to_exact(0x8000) == 0                           # -0 (sign of 0 lost)
    assert to_exact(0x007F) == 0                           # subnormal flushed to 0
    assert to_exact(0x7F7F) == Fraction(255,128) * 2**127  # largest finite

    assert mul_exact(0x3F80, 0x3F80) == 1                   #  1.0 *  1.0
    assert mul_exact(0xBF80, 0xBF80) == 1                   # -1.0 * -1.0
    assert mul_exact(0x0000, 0x0000) == 0                   #   +0 *  +0
    assert mul_exact(0x3FC0, 0x3FC0) == Fraction(9, 4)      # 1.5 * 1.5
    assert mul_exact(0x3FC0, 0xC000) == -3                  # 1.5 * -2.0
    assert mul_exact(0x3F81, 0x3F81) == 1 + Fraction(1,64) + Fraction(1,16384)

    assert add_exact(to_exact(0x3F80), 0x3F80) == 2  #  1.0 +  1.0
    assert add_exact(to_exact(0xBF80), 0xBF80) == -2 # -1.0 * -1.0
    assert add_exact(to_exact(0x0000), 0x0000) == 0  #   +0 *  +0
    assert add_exact(mul_exact(0x3F81, 0x3F81), 0x3F80) == 2 + Fraction(1,64) + Fraction(1,16384)

    print("Assertions passed")

    


