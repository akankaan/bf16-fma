# Python reference model for the validation of the Bfloat16 FMU (Fused Multiply Unit)

# Author: Kaan Akan
# Date  : July 20, 2026

def decode_bits(u: int):
    # u: bf16 as a 16-bit unsigned int with the {sign, exp, mantissa} format
    sign_bit        = (u >> 15) & (0x1)  #(0b1)
    exponent_bits   = (u >> 7)  & (0xFF) #(0b1111_1111)
    mantissa_bits   = (u)       & (0x7F) #(0b0111_1111)

    return sign_bit, exponent_bits, mantissa_bits


    