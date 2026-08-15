import reference_model

from .vector_common import random_finite_bf16_generation

SEED = 1
SPECIAL_VALUES = [0x7FC0, 0x7F80, 0xFF80, 0x0000, 0x8000, 0x0080, 0x7F7F, 0x3FC0]

def fma_random_vectors(rng, n):
    vectors = []
    for i in range(0, n):
        vectors.append((random_finite_bf16_generation(rng),
                        random_finite_bf16_generation(rng),
                        random_finite_bf16_generation(rng)))
    return vectors

def fma_special_vectors():
    vectors = []
    for a in SPECIAL_VALUES:
        for b in SPECIAL_VALUES:
            for c in SPECIAL_VALUES:
                vectors.append((a, b, c))
    return vectors

def fma_directed_vectors():
    vectors = []

    # Simple arithmetic and signs
    vectors.extend([
        (0x3F80, 0x3F80, 0x0000),  #  1.0 * 1.0 + 0.0 = 1.0
        (0x3F80, 0x4000, 0x4040),  #  1.0 * 2.0 + 3.0 = 5.0
        (0xBF80, 0x4000, 0x4040),  # -1.0 * 2.0 + 3.0 = 1.0
        (0x3F80, 0x4000, 0xC040),  #  1.0 * 2.0 - 3.0 = -1.0
        (0x3FC0, 0x4000, 0x3F00),  #  1.5 * 2.0 + 0.5 = 3.5
    ])

    # Signed zero and DAZ
    vectors.extend([
        (0x0000, 0x3F80, 0x8000),  # +0 + -0 = +0
        (0x8000, 0x3F80, 0x8000),  # -0 + -0 = -0
        (0x007F, 0x3F80, 0x3F80),  # subnormal a treated as zero, DAZ
        (0x3F80, 0x3F80, 0x807F),  # subnormal c treated as zero, DAZ
    ])
    
    # Cancellation
    vectors.extend([
        (0x3F80, 0x3F80, 0xBF80),  # exact cancellation (+1 + -1)
        (0xBF80, 0x3F80, 0x3F80),  # exact cancellation (-1 + +1)
        (0x3F81, 0x3F81, 0xBF82),  # catastrophic cancellation, residual is +2^-14
        (0xBF81, 0x3F81, 0x3F82),  # catastrophic cancellation, residual is -2^-14
    ])

    # Rounding
    vectors.extend([
        (0x3F80, 0x3F80, 0x3B00),  # below halfway between 0x3F80 and 0x3F81 (1 +   2^-9)
        (0x3F80, 0x3F80, 0x3BC0),  # above halfway between 0x3F80 and 0x3F81 (1 + 3*2^-9)
        (0x3F80, 0x3F80, 0x3B80),  # exact tie with even down   (1 +   2^-8)
        (0x3F80, 0x3F80, 0x3C40),  # exact tie with even up     (1 + 3*2^-8)
        (0x3F80, 0x3FFF, 0x3B80),  # tie between 0x3FFF and 0x4000, rounding carries to exponent
    ])

    # Overflow and underflow 
    vectors.extend([
        (0x0080, 0x3F00, 0x0000),  # +2^-127 flushes to +0
        (0x8080, 0x3F00, 0x0000),  # -2^-127 flushes to -0
        (0x7F7F, 0x4000, 0x0000),  # positive overflow, largest pos finite * 2
        (0xFF7F, 0x4000, 0x0000),  # negative overflow, largest neg finite * 2
    ])

    return vectors

# Write the expected value of given vectors after fma operation
def write_vector_results_fma(path, vectors):
    with open(path, "w") as f:
        for a, b, c in vectors:

            expected_result = reference_model.fma_bf16_ref(a, b, c)

            # Writes input floats and their corresponding expected value
            f.write(f"{a:04x} {b:04x} {c:04x} {expected_result:04x}\n")
    print(f"{path}: {len(vectors)} vectors")
