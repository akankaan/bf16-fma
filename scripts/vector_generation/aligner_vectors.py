import reference_model

from .vector_common import random_finite_bf16_generation

SEED = 1

def aligner_random_vectors(rng, n):

    vectors = []

    for i in range(0, n):
        
        a = random_finite_bf16_generation(rng)
        b = random_finite_bf16_generation(rng)
        c = random_finite_bf16_generation(rng)

        (product, product_exponent, 
         unused_prod_sign, product_zero) = reference_model.multiply_ref(a, b)

        unused_c_sign, c_exponent, c_fraction = reference_model.decode_bits(c)

        c_zero = int(c_exponent == 0)

        vectors.append((product, product_zero, product_exponent, 
                        c_zero,  c_exponent,   c_fraction))

    return vectors

def aligner_edge_shift_vectors():

    vectors = []

    product, product_exponent, product_zero = 0xC000, 100, 0

    # Go through shift = 100 - c_exp + 11 (from +31 down to -9)
    for c_exponent in range(80, 121):
        c_fraction, c_zero = 0x55, 0     # Chose non-zero fraction so sticky can go high

        vectors.append((product, product_zero, product_exponent,
                        c_zero, c_exponent, c_fraction))
    return vectors

# Write the expected value of given vectors after alignment operation
def write_vector_results_aligner(path, vectors):
    with open(path, "w") as f:
        for (product, product_zero, product_exponent,
             c_zero,  c_exponent,   c_fraction) in vectors:

            (aligned_product, aligned_addend,
             sticky, aligned_exponent) = reference_model.aligner_ref(product, product_zero, product_exponent,
                                                                     c_zero,  c_exponent,   c_fraction)
            
            line = (f"{product:04x} {product_zero:01x} {product_exponent & 0x3FF:03x} "
                    f"{c_zero:01x} {c_exponent:02x} {c_fraction:02x} "
                    f"{aligned_product:07x} {aligned_addend:07x} {sticky:01x} {aligned_exponent & 0x3FF:03x}")

            f.write(line + "\n")

    print(f"{path}: {len(vectors)} vectors")
