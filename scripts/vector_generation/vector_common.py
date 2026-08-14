def bf16(sign, exponent, fraction):
    return (sign << 15) | (exponent << 7) | fraction

# Generate random vector that doesn't have special flags
def random_normal_bf16_generation(rng):
    return (rng.randint(0,1) << 15) | (rng.randint(1,254) << 7 ) | (rng.randint(0,127))

# Generate finite random vector that can be zero and subnormal 
def random_finite_bf16_generation(rng):
    return (rng.randint(0,1) << 15) | (rng.randint(0,254) << 7 ) | (rng.randint(0,127))
