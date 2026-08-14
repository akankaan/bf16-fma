import reference_model

from .vector_common import bf16, random_normal_bf16_generation

SEED = 1

def multiplier_random_vectors(rng, n):
    vectors = []
    for i in range(0, n):
        vectors.append((random_normal_bf16_generation(rng),
                        random_normal_bf16_generation(rng)))
    return vectors

def multiplier_exhaustive_vectors():
    vectors = []

    # The following should test the multiplier exhaustively as exponent,
    # fraction, sign, and zero are computed independently:

    # Every fraction input pair with fixed exponent and sign
    for a_fraction in range (0,128):
        for b_fraction in range (0,128):
            vectors.append((bf16(0, 128, a_fraction), bf16(0, 128, b_fraction)))

    # Every exponent pair with fixed fraction and sign, except zeros
    for a_exponent in range(1, 255):
        for b_exponent in range(1, 255):
            vectors.append((bf16(0, a_exponent, 0), bf16(0, b_exponent, 0)))

    # Every sign pair with exponent and fraction fixed
    for a_sign in range(0, 2):
        for b_sign in range(0, 2):
            vectors.append((bf16(a_sign, 128, 0), bf16(b_sign, 128, 0)))

    # Zero and subnormal values
    for a_exponent in (0, 127):
        vectors.append((bf16(0, a_exponent, 0), bf16(0, 0, 0)))
        vectors.append((bf16(0, a_exponent, 0), bf16(0, 0, 0x40)))
    for b_exponent in (0, 127):
        vectors.append((bf16(0, 0, 0), bf16(0, b_exponent, 0)))
        vectors.append((bf16(0, 0, 0x40), bf16(0, b_exponent, 0)))

    return vectors

# Write the expected value of given vectors after multiplier operation
def write_vector_results_multiplier(path, vectors):
    with open(path, "w") as f:
        for a, b in vectors:

            product, exponent, sign, zero = reference_model.multiply_ref(a, b)

            # Writes multiplicands and their expected multiplier output values
            # & 0x3FF writes the exponent as 10-bit two's complement
            line = f"{a:04x} {b:04x} {product:04x} {exponent & 0x3FF:03x} " \
                   f"{sign:01x} {zero:01x}"

            f.write(line + "\n")

    print(f"{path}: {len(vectors)} vectors")
