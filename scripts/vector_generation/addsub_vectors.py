import reference_model

from .vector_common import random_finite_bf16_generation

SEED = 1

def addsub_directed_vectors():

    vectors = []
    # Vector order: aligned_product,  aligned_addend, sticky, 
    #               aligned_exponent, product_sign,   c_sign

    # Sign combinations
    vectors.extend([
        (0xAAAA, 0xAA, 0, 120, 0, 0),
        (0xAAAA, 0xAA, 0, 120, 0, 1),
        (0xAAAA, 0xAA, 0, 120, 1, 0),
        (0xAAAA, 0xAA, 0, 120, 1, 1),    
    ])

    # Cancellations
    vectors.extend([
        # Exact
        (0x00AA, 0xAA, 0, 120, 0, 1),
        (0x00AA, 0xAA, 0, 120, 1, 0),
        # Catastrophic
        (0x00AA, 0xA9, 0, 120, 0, 1),
        (0x00AA, 0xA9, 0, 120, 1, 0),
        (0x00AA, 0xAB, 0, 120, 0, 1),   
        (0x00AA, 0xAB, 0, 120, 1, 0),    
    ])

    # Sticky in addition
    vectors.extend([
        (0xAAAA, 0xAA, 1, 120, 0, 0),
        (0xAAAA, 0xAA, 1, 120, 1, 1),
    ])

    # Sticky decrement and its zero special case
    vectors.extend([
        # Exact cancellation causes magnitude equal zero special case,
        # so decrement shouldn't go high
        (0x00BB, 0xBB, 1, 120, 0, 1),
        (0x00BB, 0xBB, 1, 120, 1, 0),
        (0x00AA, 0xAA, 1, 120, 0, 1),
        (0x00AA, 0xAA, 1, 120, 1, 0),

        # Magnitude isn't exactly zero so decrement should go high
        (0xC0BB, 0xBB, 1, 120, 0, 1),
        (0xC0BB, 0xBB, 1, 120, 1, 0),
        (0x00AA, 0xA9, 1, 120, 0, 1),
        (0x00AA, 0xBA, 1, 120, 1, 0),
    ])

    return vectors

# Generate random input vectors for the addsub unit
def addsub_random_vectors(rng, n):

    vectors = []

    for i in range(0, n):
        a = random_finite_bf16_generation(rng)
        b = random_finite_bf16_generation(rng)
        c = random_finite_bf16_generation(rng)

        (product, product_exponent, 
         product_sign, product_zero) = reference_model.multiply_ref(a, b)

        c_sign, c_exponent, c_fraction = reference_model.decode_bits(c)

        c_zero = int(c_exponent == 0)

        (aligned_product, aligned_addend,
        sticky, aligned_exponent) = reference_model.aligner_ref(product, product_zero, product_exponent,
                                                                        c_zero,  c_exponent,   c_fraction)

        vectors.append((aligned_product,  aligned_addend, sticky, 
                        aligned_exponent, product_sign,   c_sign))

    return vectors

# Write the expected value of given input vectors after addsub operation
def write_vector_results_addsub(path, vectors):
    with open(path, "w") as f:

        for (aligned_product,  aligned_addend, sticky, 
             aligned_exponent, product_sign, c_sign) in vectors:

            (sum, sum_sign, 
             sum_exponent, sum_sticky) = reference_model.addsub_ref(aligned_product,  aligned_addend, sticky, 
                                                                     aligned_exponent, product_sign, c_sign)
            
            line = (f"{aligned_product:07x} {aligned_addend:07x} {sticky:01x} {aligned_exponent & 0x3FF:03x} "
                    f"{product_sign:01x} {c_sign:01x} "
                    f"{sum:07x} {sum_sign:01x} {sum_exponent & 0x3FF:03x} {sum_sticky:01x}")

            f.write(line + "\n")

    print(f"{path}: {len(vectors)} vectors")
