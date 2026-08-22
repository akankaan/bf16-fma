import reference_model

from .vector_common import random_finite_bf16_generation

SEED = 1

def rounder_directed_vectors():

    vectors = []
    # Vector order: norm_significand, guard,     sticky, 
    #               norm_exponent,    norm_sign, is_zero

    # Zero and underflow
    vectors.extend([
        (0x00, 0, 0, 113, 0, 1), # exact cancellation
        (0x80, 0, 0,  -1, 0, 0), # exponent less than zero
        (0x80, 0, 0,   0, 0, 0), # exponent equal to  zero
        (0x80, 0, 0,   0, 1, 0), # exponent equal to  zero, sign negative
    ])

    # RNE 
    vectors.extend([
        (0x80, 0, 0, 127, 0, 0), # exact, no rounding
        (0x80, 0, 1, 127, 0, 0), # sticky alone, no rounding
        (0x80, 1, 1, 127, 0, 0), # sticky and guard high, round
        (0x80, 1, 0, 127, 0, 0), # exact tie, even LSB so no rounding
        (0x81, 1, 0, 127, 0, 0), # exact tie, odd LSB so round up to even
    ])

    # Rounding causes exponent increase
    vectors.extend([
        (0xFF, 1, 0, 127, 0, 0),
        (0xFF, 1, 1, 127, 0, 0),
        (0xFF, 1, 0,   0, 0, 0), # carry makes subnormal smallest normal
        (0xFF, 1, 0,  -1, 0, 0), # still flushed as carry makes exponent 0 from -1
    ])

    # Overflow 
    vectors.extend([
        (0xFF, 0, 0, 254, 0, 0), # maximum finite, no rounding
        (0xFF, 1, 0, 254, 0, 0), # maximum magnitude positive finite becomes +inf with rounding
        (0xFF, 1, 0, 254, 1, 0), # maximum magnitude negative finite becomes -inf with rounding
        (0x80, 0, 0, 255, 0, 0), # exponent is already overflown without rounding 
    ])

    return vectors

# Generate random input vectors for the rounder unit
def rounder_random_vectors(rng, n):

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

        (sum, sum_sign, 
         sum_exponent, sum_sticky) = reference_model.addsub_ref(aligned_product,  aligned_addend, sticky, 
                                                                aligned_exponent, product_sign,   c_sign)

        (norm_significand, guard, sticky, 
         norm_exponent, norm_sign, is_zero) = reference_model.normalizer_ref(sum, sum_sign,
                                                                             sum_exponent, sum_sticky)
        
        vectors.append((norm_significand, guard, sticky, 
                        norm_exponent, norm_sign, is_zero))

    return vectors

# Write the expected value of given input vectors after rounder operation
def write_vector_results_rounder(path, vectors):
    with open(path, "w") as f:

        for (norm_significand, guard, sticky, 
             norm_exponent, norm_sign, is_zero) in vectors:

            (rounded_result) = reference_model.rounder_ref(norm_significand, guard, sticky, 
                                                              norm_exponent, norm_sign, is_zero)
            
            line = (f"{norm_significand:02x} {guard:01x} {sticky:01x} "
                    f"{norm_exponent & 0x3FF:03x} {norm_sign:01x} {is_zero:01x} "
                    f"{rounded_result:04x}")

            f.write(line + "\n")

    print(f"{path}: {len(vectors)} vectors")
