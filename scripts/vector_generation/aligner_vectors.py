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

def aligner_exhaustive_shift_sweep_vectors():

    vectors = []

    product_list    = [0xC000, 0xAAAA, 0x5555, 0xFE01]
    c_fraction_list = [0x00,   0x2A,   0x55,   0x7F]

    # Go through shift -368 (-125 - 254 + 11) to 391 (381 - 1 + 11)
    for shift in range(-368, 391 + 1):

        if shift < 0:
            c_exponent = 254
        else: 
            c_exponent = 1

        # Rearrange, shift = product_exponent - c_exponent + 11
        product_exponent = shift + c_exponent - 11
        for product in product_list:
            for c_fraction in c_fraction_list:
                vectors.append((product, 
                                0, #product_zero 
                                product_exponent, 
                                0, #c_zero
                                c_exponent, 
                                c_fraction))

    return vectors

def aligner_directed_vectors():

    vectors = []
    # Vector order: product, product_zero, product_exponent,
    #               c_zero,  c_exponent,   c_fraction

    # Zero handling
    vectors.extend([
        # Product and addend zero; product zero and subnormal addend
        (0x0000, 1, 0, 1, 0, 0x00),
        (0x0000, 1, 0, 1, 0, 0x7F),

        # Addend is zero or subnormal
        (0xC000, 0,  1, 1, 0, 0x00),
        (0xC000, 0,  1, 1, 0, 0x7F),

        # c_dominates with negative shift without product_zero or c_zero high
        (0xC000, 0, 100, 0, 211, 0x7F), # (100 - 211 + 11 = -100)
        (0xC000, 0, -12, 0, 10,  0x7F), # (-12  - 10 + 11 = -11)
        (0xC000, 0,  22, 0, 52,  0x7F), # (+22  - 52 + 11 = -19)
        (0xC000, 0, 100, 0, 112, 0x55), # (100 - 112 + 11 = -1)
        (0xC000, 0, -47, 0, 254, 0x55), # (-47 - 254 + 11 = -290)

        # product_zero forces c_dominates with both positive and negative shift
        (0x0000, 1, 0, 0, 1,   0x00), # (0 - 1   + 11 = 10)
        (0x0000, 1, 0, 0, 254, 0x00), # (0 - 254 + 11 = -243)
        (0x0000, 1, 0, 0, 12,  0x7F), # (0 - 12  + 11 = -1)

        # c_dominates doesn't go high with negative shift as c_zero is high
        (0xC000, 0, -100, 1, 0, 0x00),
        (0xD020, 0, -47,  1, 0, 0x55),
    ])

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
