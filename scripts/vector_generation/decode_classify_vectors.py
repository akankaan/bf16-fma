import reference_model

from .vector_common import random_finite_bf16_generation

SEED = 1

def decode_classify_random_vectors(rng, n):

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
