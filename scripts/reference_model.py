# Python reference model for the validation of the Bfloat16 FMU (Fused Multiply Unit)

# Author: Kaan Akan
# Date  : July 20, 2026

from fractions import Fraction
import math

def decode_bits(u: int):
    # u: bf16 as a 16-bit unsigned int with the {sign, exp, mantissa} format
    sign_bit        = (u >> 15) & (0x1)  #(0b1)
    exponent_bits   = (u >> 7)  & (0xFF) #(0b1111_1111)
    mantissa_bits   = (u)       & (0x7F) #(0b0111_1111)

    return sign_bit, exponent_bits, mantissa_bits

# Generates the exact value of bf16-encoded u with the implementation rules
def bf16_to_exact(u: int):

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

# Returns exact value of the multiplication two bf-16 encoded inputs
def mul_exact(a: int, b: int):

    return bf16_to_exact(a) * bf16_to_exact(b)

# Returns exact value of the addition of the unrounded intermediate,
# hence the Fraction input, with the second bf-16 encoded input
def add_exact(intermediate: Fraction, c: int):

    return intermediate + bf16_to_exact(c)

# Returns the RNE rounded bf16 representation of number corresponding to given
# sign bit and exact magnitude. 
def round_exact_to_bf16(sign_bit: int, magnitude: Fraction):

    assert magnitude >= 0, "Magnitude cannot be less than zero. Use correct sign bit."

    # Return 0 encoding with matching sign for 0 magnitude
    if magnitude == 0:
        return sign_bit << 15
    
    exponent    = 0
    significand = magnitude
    
    # If significand larger than or equal to the radix, increase exponent by one
    # and shift significand to the right. Do opposite if significand smaller than radix.
    while significand >= 2:
        exponent    = exponent + 1
        significand = significand / 2
    while significand < 1:
        exponent    = exponent - 1
        significand = significand * 2

    # Zero or subnormal as indicated by exponent is flushed to zero
    # Check before possible rounding up
    if ((exponent + 127) <= 0):
        return sign_bit << 15

    # Get the exact fraction in [0,128) after the hidden 1
    fraction =  (significand - 1) * 128

    # Floor significand fraction integer to get into form representable
    # by the bf16 precision
    fraction_floor = math.floor(fraction)
    remainder      = fraction - fraction_floor

    # If remainder between exact and floored significand is more than half ulp, round up.
    # If remainder is exactly half an ulp and last digit is 1, round up as ties break to even.
    # For remaining cases, floored (meaning already round down) is appopriate.
    if ((remainder > Fraction(1,2)) or 
       ((remainder == Fraction(1,2)) and (fraction_floor  & (0b1)))):
        fraction_floor = fraction_floor + 1

    # Check if rounding up may have caused fraction to exceed maximum
    # If so, increase exponent by 1 and set fraction to 0, so significand is hidden 1
    if (fraction_floor == 128):
        fraction_floor = 0
        exponent = exponent + 1

    biased_exponent = exponent + 127

    # Check for overflow after possible rounding up, if so return pos inf encoding
    if ((exponent + 127) >= 255):
        return (sign_bit << 15) | 0x7F80
    
    return (sign_bit << 15) | (biased_exponent << 7) | fraction_floor

# Smoke testing inline asserts only fire in direct execution
if (__name__ == "__main__"):

    assert decode_bits(0b1111_1111_1111_1111) == (0b1, 0b1111_1111, 0b1111_111)
    assert decode_bits(0b0111_1111_1111_1111) == (0b0, 0b1111_1111, 0b1111_111)
    assert decode_bits(0b0101_0011_1101_1011) == (0b0, 0b1010_0111, 0b1011_011)
    assert decode_bits(0b1010_1100_0010_0100) == (0b1, 0b0101_1000, 0b0100_100)

    assert bf16_to_exact(0x3F80) == 1                           # 1.0
    assert bf16_to_exact(0xBF80) == -1                          # -1.0
    assert bf16_to_exact(0xC000) == -2                          # -2.0
    assert bf16_to_exact(0x3FC0) == Fraction(3, 2)              # 1.5
    assert bf16_to_exact(0x3F00) == Fraction(1, 2)              # 0.5
    assert bf16_to_exact(0x0080) == Fraction(2) ** -126         # smallest normal
    assert bf16_to_exact(0x0000) == 0                           # +0
    assert bf16_to_exact(0x8000) == 0                           # -0 (sign of 0 lost)
    assert bf16_to_exact(0x007F) == 0                           # subnormal flushed to 0
    assert bf16_to_exact(0x7F7F) == Fraction(255,128) * 2**127  # largest finite

    assert mul_exact(0x3F80, 0x3F80) == 1                   #  1.0 *  1.0
    assert mul_exact(0xBF80, 0xBF80) == 1                   # -1.0 * -1.0
    assert mul_exact(0x0000, 0x0000) == 0                   #   +0 *  +0
    assert mul_exact(0x3FC0, 0x3FC0) == Fraction(9, 4)      # 1.5 * 1.5
    assert mul_exact(0x3FC0, 0xC000) == -3                  # 1.5 * -2.0
    assert mul_exact(0x3F81, 0x3F81) == 1 + Fraction(1,64) + Fraction(1,16384)

    assert add_exact(bf16_to_exact(0x3F80), 0x3F80) == 2  #  1.0 +  1.0
    assert add_exact(bf16_to_exact(0xBF80), 0xBF80) == -2 # -1.0 * -1.0
    assert add_exact(bf16_to_exact(0x0000), 0x0000) == 0  #   +0 *  +0
    assert add_exact(mul_exact(0x3F81, 0x3F81), 0x3F80) == 2 + Fraction(1,64) + Fraction(1,16384)

    assert round_exact_to_bf16(0, 0)  ==  0x0000 #  +0 ->  0
    assert round_exact_to_bf16(1, 0)  ==  0x8000 #  -0 ->  0
    assert round_exact_to_bf16(0, Fraction(32)) ==  0x4200 #  32 ->  32 - exact 
    assert round_exact_to_bf16(1, Fraction(32)) ==  0xC200 # -32 -> -32 - exact 

    assert round_exact_to_bf16(0, 1 + Fraction(1,256)) == 0x3F80 # Tie rounds to even, so down
    assert round_exact_to_bf16(0, 1 + Fraction(1,256) - Fraction(2)**-80) == 0x3F80 # Tie is broken but still rounds down
    assert round_exact_to_bf16(0, 1 + Fraction(1,256) + Fraction(2)**-80) == 0x3F81 # Tie is broken but rounds up
    assert round_exact_to_bf16(0, 1 + Fraction(3,256)) == 0x3F82 # Tie rounds to even, so up
    assert round_exact_to_bf16(0, 1 + Fraction(5,256)) == 0x3F82 # Tie rounds to even, so down

    assert round_exact_to_bf16(0, 2 - Fraction(1, 512)) == 0x4000 # Rounds up causes to exceed signicand range, see if shifted after rounding
    assert round_exact_to_bf16(0, 2 - Fraction(1, 256)) == 0x4000 # Tie rounds up, check after rounding
    assert round_exact_to_bf16(0, 2 - Fraction(1, 128)) == 0x3FFF # No roundung, just max fraction

    max_float = Fraction(255,128) * Fraction(2)**127
    assert round_exact_to_bf16(0, max_float) == 0x7F7F                        # Max float
    assert round_exact_to_bf16(0, max_float + Fraction(2)**119) == 0x7F80     # Tie rounds up, overflow to inf
    assert round_exact_to_bf16(0, max_float + Fraction(2)**119 - 1) == 0x7F7F # One less than tie to infinity rounds down
    assert round_exact_to_bf16(1, Fraction(2)**128) == 0xFF80                 # Negative signed overflow

    min_normal = Fraction(2)**-126
    assert round_exact_to_bf16(0, min_normal) == 0x0080               # Min normal
    assert round_exact_to_bf16(0, min_normal / Fraction(2)) == 0x0000 # Below normal: FTZ

    for u in range(0xFFFF + 1):
        sign, exponent, fraction = decode_bits(u)
        if ((exponent == 0x00) or (exponent == 0xFF)):
            continue
        assert round_exact_to_bf16(sign, abs(bf16_to_exact(u))) == u

    print("Assertions passed")

    


