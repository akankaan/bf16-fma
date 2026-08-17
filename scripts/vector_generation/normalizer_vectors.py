import reference_model

from .vector_common import random_finite_bf16_generation

SEED = 1

def normalizer_directed_vectors():

    vectors = []
    # Vector order: sum, sum_sign, sum_exponent, sum_sticky

    # Zero handling 
    vectors.extend([
        (0x0000000, 0,   0,   0),
        (0x0000000, 1,   0,   0),
        (0x0000000, 1,   127, 0), # exact cancellation
    ])

    # Leading one shift sweep
    for leading_one_pos in range(26):
        vectors.append((1 << leading_one_pos, 0, 127, 0))

    # Guard and sticky
    vectors.extend([
        (0x0000000, 0, 127, 0), # guard=0, sticky=0
        (0x0000000, 0, 127, 1), # guard=0, sticky=1

        (0x0008000, 0, 127, 0), # guard=0, sticky=0
        (0x0008000, 0, 127, 1), # guard=0, sticky=1
        (0x0008080, 0, 127, 0), # guard=1, sticky=0
        (0x0008080, 0, 127, 1), # guard=1, sticky=1
        (0x0008040, 0, 127, 0), # guard=0, sticky=1
        (0x00080C0, 0, 127, 0), # guard=1, sticky=1
        (0x00080C0, 0, 127, 1), # guard=1, sticky=1 (from both shift and sum_sticky)
    ]) 

    return vectors

# Generate random input vectors for the normalizer unit
def normalizer_random_vectors(rng, n):

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
                                                                aligned_exponent, product_sign, c_sign)
        
        vectors.append((sum, sum_sign, sum_exponent, sum_sticky))

    return vectors

# Write the expected value of given input vectors after normalizer operation
def write_vector_results_normalizer(path, vectors):
    with open(path, "w") as f:

        for (sum, sum_sign, sum_exponent, sum_sticky) in vectors:

            (norm_significand, guard, sticky, 
             norm_exponent, norm_sign, is_zero) = reference_model.normalizer_ref(sum, sum_sign,
                                                                                 sum_exponent, sum_sticky)
            
            line = (f"{sum:07x} {sum_sign:01x} {sum_exponent & 0x3FF:03x} {sum_sticky:01x} "
                    f"{norm_significand:02x} {guard:01x} {sticky:01x} "
                    f"{norm_exponent & 0x3FF:03x} {norm_sign:01x} {is_zero:01x}")

            f.write(line + "\n")

    print(f"{path}: {len(vectors)} vectors")
