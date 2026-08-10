# Python reference model for the validation of the Bfloat16 FMA (Fused Multiply Add) unit

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

def fma_bf16_ref(a:int, b:int, c:int):
    # Flag handling
    sign_a, exponent_a, fraction_a = decode_bits(a)
    sign_b, exponent_b, fraction_b = decode_bits(b) 
    sign_c, exponent_c, fraction_c = decode_bits(c) 

    a_inf  = (exponent_a == 255) and (fraction_a == 0)
    a_nan  = (exponent_a == 255) and (fraction_a != 0)
    a_zero = (exponent_a == 0) # Subnormals are considered zero

    b_nan  = (exponent_b == 255) and (fraction_b != 0)
    b_inf  = (exponent_b == 255) and (fraction_b == 0)
    b_zero = (exponent_b == 0)

    c_inf  = (exponent_c == 255) and (fraction_c == 0)
    c_nan  = (exponent_c == 255) and (fraction_c != 0)  

    # Return NaN for any NaN input
    if (a_nan or b_nan or c_nan):
        return 0x7FC0
    # Return NaN when one multiplicand is infinite and the other zero
    elif ((a_inf and b_zero) or (a_zero and b_inf)):
        return 0x7FC0
    # Return NaN when inf multiplication's sign doesn't match infinite addend's sign
    elif ((a_inf or b_inf) and (c_inf) and ((sign_a ^ sign_b) != sign_c)):
        return 0x7FC0
    # Return inf, with appopriate sign, when at least one multiplicand is inf.
    # c is either finite or same signed inf
    elif (a_inf or b_inf):
        return ((sign_a ^ sign_b) << 15) | 0x7F80
    # Return inf, with appopriate sign, when addend is inf, multiplicands are finite
    elif (c_inf):
        return (sign_c << 15) | 0x7F80
    # No special flags detected, do arithmetic
    else:
        result = add_exact(mul_exact(a,b), c)
        if result > 0:
            sign_result = 0
        elif result < 0:
            sign_result = 1
        else:
            # Fraction(0) has no sign and requires sign to be recovered
            # 0 happens either because +-0 result of multiplication and c were added,
            # or opposing signed values got cancelled. Only case that results in negative 0 sign
            # is when negative zeros are added, so:
            #   (-0) + (-0) = -0      ->  the only path to -0
            #   (+0) + (+0) = +0
            #   (+0) + (-0) = +0          (IEEE-754 zero-sum rule; +0 for RNE)
            #   exact cancellation = +0   (IEEE-754 zero-sum rule; +0 under RNE)
            sign_result = ((sign_a ^ sign_b) == 1) and (sign_c == 1)
              
        return round_exact_to_bf16(sign_result, abs(result))

# Returns the expected bf16_multiplier output value given two bf16 multiplicands 
# in the following format: (product, product_exponent, product_sign, product_zero)
# Note that the two's complement conversion happens in the vector generation
def multiply_ref(a: int, b: int):
    sign_a, exponent_a, a_fraction = decode_bits(a)
    sign_b, exponent_b, b_fraction = decode_bits(b)

    product_sign = sign_a ^ sign_b
    product_zero = (exponent_a == 0) or (exponent_b == 0)

    # Add the implicit one to the MSB
    mantissa_a = (1 << 7) | a_fraction
    mantissa_b = (1 << 7) | b_fraction

    # Directly assign zeros to product and exponent when product zero is true
    if (product_zero):
        product          = 0
        product_exponent = 0
    else:
        product          = mantissa_a * mantissa_b
        product_exponent = exponent_a + exponent_b - 127

    return product, product_exponent, product_sign, product_zero

# Returns the expected bf16_aligner outputs for the aligner's inputs
def aligner_ref(product, product_zero, product_exponent, 
                c_zero,  c_exponent,   c_fraction):

    WIDTH       = 26
    SHIFT_CONST = 11
    MASK        = (1 << WIDTH) - 1 # helps truncate to ints to explicit width

    # Form addend mantissa with implicit 1, zero denormals
    c_mantissa = 0 if c_zero else ((1 << 7) | c_fraction)

    # Locate c at the top of the frame, [25:18]
    c_home = c_mantissa << (WIDTH - 8)

    # Determine how far c slides down
    shift = product_exponent - c_exponent + SHIFT_CONST

    c_dominates = (product_zero) or (shift < 0)

    if c_dominates:
        aligned_product  = 0
        aligned_addend   = c_home
        sticky           = 1 if product != 0 else 0
        aligned_exponent = c_exponent - SHIFT_CONST
    else:
        aligned_product  = product
        aligned_addend   = (c_home >> shift) & MASK
        sticky           = 1 if (c_home & ((1 << shift) - 1)) != 0 else 0
        aligned_exponent = product_exponent

    return aligned_product, aligned_addend, sticky, aligned_exponent

# Returns the expected bf16_addsub outputs for the addsub's inputs
def addsub_ref(aligned_product, aligned_addend, sticky, aligned_exponent,
               product_sign, c_sign):

    signed_product = -aligned_product if product_sign else aligned_product
    signed_addend  = -aligned_addend  if c_sign       else aligned_addend
    signed_sum     = signed_product + signed_addend

    sum_sign = 1 if (signed_sum < 0) else 0
    magnitude = abs(signed_sum)

    # Borrow using subtrahend sticky during effective subtraction
    effective_subtraction = product_sign ^ c_sign
    borrow = effective_subtraction & sticky
    # Prevent going down from zero when already at zero
    sum = magnitude - borrow if magnitude > 0 else magnitude

    sum_sticky   = sticky
    sum_exponent = aligned_exponent
    return (sum, sum_sign, sum_exponent, sum_sticky)

# Returns the expected bf16_normalizer outputs for the normalizer's inputs
def normalizer_ref(sum, sum_sign, sum_exponent, sum_sticky):

    is_zero = int(sum == 0)
    norm_sign = sum_sign

    # Find leading one's position
    leading_one_pos = sum.bit_length() - 1 if sum else 0

    # Shift leading one to bit 26 of the frame
    shifted_sum = sum << (26 - leading_one_pos)

    norm_significand = shifted_sum >> 19
    guard            = (shifted_sum >> 18) & 1
    sticky           = int(bool(shifted_sum & ((1 << 18) - 1)) or sum_sticky)
    norm_exponent    = sum_exponent + leading_one_pos - 14

    return (norm_significand, guard, sticky, norm_exponent, norm_sign, is_zero)

# Smoke testing inline asserts only fire in direct execution
if (__name__ == "__main__"):

    # -------------------------------------------------------------------
    # Decode bits test cases
    # -------------------------------------------------------------------
    assert decode_bits(0b1111_1111_1111_1111) == (0b1, 0b1111_1111, 0b1111_111)
    assert decode_bits(0b0111_1111_1111_1111) == (0b0, 0b1111_1111, 0b1111_111)
    assert decode_bits(0b0101_0011_1101_1011) == (0b0, 0b1010_0111, 0b1011_011)
    assert decode_bits(0b1010_1100_0010_0100) == (0b1, 0b0101_1000, 0b0100_100)

    # -------------------------------------------------------------------
    # Bf16 to exact conversion test cases
    # -------------------------------------------------------------------
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

    # -------------------------------------------------------------------
    # Multiplication test cases
    # -------------------------------------------------------------------
    assert mul_exact(0x3F80, 0x3F80) == 1                   #  1.0 *  1.0
    assert mul_exact(0xBF80, 0xBF80) == 1                   # -1.0 * -1.0
    assert mul_exact(0x0000, 0x0000) == 0                   #   +0 *  +0
    assert mul_exact(0x3FC0, 0x3FC0) == Fraction(9, 4)      # 1.5 * 1.5
    assert mul_exact(0x3FC0, 0xC000) == -3                  # 1.5 * -2.0
    assert mul_exact(0x3F81, 0x3F81) == 1 + Fraction(1,64) + Fraction(1,16384)

    # -------------------------------------------------------------------
    # Addition test cases
    # -------------------------------------------------------------------
    assert add_exact(bf16_to_exact(0x3F80), 0x3F80) == 2  #  1.0 +  1.0
    assert add_exact(bf16_to_exact(0xBF80), 0xBF80) == -2 # -1.0 * -1.0
    assert add_exact(bf16_to_exact(0x0000), 0x0000) == 0  #   +0 *  +0
    assert add_exact(mul_exact(0x3F81, 0x3F81), 0x3F80) == 2 + Fraction(1,64) + Fraction(1,16384)

    # -------------------------------------------------------------------
    # Round exact to bf16 test cases
    # -------------------------------------------------------------------
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
    
    # -------------------------------------------------------------------
    # FMA reference test cases
    # -------------------------------------------------------------------
    assert fma_bf16_ref(0x0000, 0x0000, 0x0000) == 0x0000 # (+0) * (+0)  + (+0)  = +0 
    assert fma_bf16_ref(0x8000, 0x0000, 0x0000) == 0x0000 # (-0) * (+0)  + (+0)  = +0 
    assert fma_bf16_ref(0x8000, 0x0000, 0x8000) == 0x8000 # (-0) * (+0)  + (-0)  = -0 
    assert fma_bf16_ref(0x8000, 0x8000, 0x8000) == 0x0000 # (-0) * (-0)  + (-0)  = +0
    assert fma_bf16_ref(0x3F80, 0x4000, 0xC000) == 0x0000 # (+1) * (+2)  + (-2)  = +0 
    assert fma_bf16_ref(0xBF80, 0x4000, 0x4000) == 0x0000 # (-1) * (+2)  + (+2)  = +0 

    assert fma_bf16_ref(0x0000, 0x0000, 0x3F80) == 0x3F80 # (+0) * (+0)  + (+1)  = +1 
    assert fma_bf16_ref(0x3F80, 0x0000, 0x3F80) == 0x3F80 # (+1) * (+0)  + (+1)  = +1
    assert fma_bf16_ref(0x3F80, 0x3F80, 0x3F80) == 0x4000 # (+1) * (+1)  + (+1)  = +2
    assert fma_bf16_ref(0x4180, 0x4380, 0x4380) == 0x4588 # (16) * (256) + (256) = 4352
    assert fma_bf16_ref(0x3F80, 0x3F80, 0x0080) == 0x3F80 # Large multiplication + small addend

    print("Assertions passed")

    


