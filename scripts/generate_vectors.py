# Vector generation for the validation of the Bfloat16 FMA (Fused Multiply Add) unit

# Author: Kaan Akan
# Date  : July 24, 2026

import random
import reference_model

SEED = 1 # Using seed for reproducibility
FMA_RANDOM_COUNT        = 10000
MUL_RANDOM_COUNT        = 10000
ALIGNER_RANDOM_COUNT    = 10000
ADDSUB_RANDOM_COUNT     = 10000
NORMALIZER_RANDOM_COUNT = 10000
SPECIAL_VALUES = [0x7FC0, 0x7F80, 0xFF80, 0x0000, 0x8000, 0x0080, 0x7F7F, 0x3FC0]

def bf16(sign, exponent, fraction):
    return (sign << 15) | (exponent << 7) | fraction

# Generate random vector that doesn't have special flags
def random_normal_bf16_generation(rng):
    return (rng.randint(0,1) << 15) | (rng.randint(1,254) << 7 ) | (rng.randint(0,127))

# Generate random vector that can be zero and subnormal 
def random_all_bf16_generation(rng):
    return (rng.randint(0,1) << 15) | (rng.randint(0,254) << 7 ) | (rng.randint(0,127))

def fma_random_vectors(rng, n):
    vectors = []
    for i in range(0, n):
        vectors.append((random_normal_bf16_generation(rng),
                        random_normal_bf16_generation(rng),
                        random_normal_bf16_generation(rng)))
    return vectors

def fma_special_vectors():
    vectors = []
    for a in SPECIAL_VALUES:
        for b in SPECIAL_VALUES:
            for c in SPECIAL_VALUES:
                vectors.append((a, b, c))
    return vectors

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

def aligner_random_vectors(rng, n):

    vectors = []

    for i in range(0, n):
        
        a = random_all_bf16_generation(rng)
        b = random_all_bf16_generation(rng)
        c = random_all_bf16_generation(rng)

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

# Generate random input vectors for the addsub unit
def addsub_random_vectors(rng, n):

    vectors = []

    for i in range(0, n):
        a = random_all_bf16_generation(rng)
        b = random_all_bf16_generation(rng)
        c = random_all_bf16_generation(rng)

        (product, product_exponent, 
         product_sign, product_zero) = reference_model.multiply_ref(a, b)

        c_sign, c_exponent, c_fraction = reference_model.decode_bits(c)

        c_zero = int(c_exponent == 0)

        (aligned_product, aligned_addend,
        sticky, aligned_exponent) = reference_model.aligner_ref(product, product_zero, product_exponent,
                                                                        c_zero,  c_exponent,   c_fraction)

        vectors.append((aligned_product,  aligned_addend, sticky, 
                        aligned_exponent, product_sign, c_sign))

    return vectors

# Generate random input vectors for the normalizer unit
def normalizer_random_vectors(rng, n):

    vectors = []

    for i in range(0, n):
        a = random_all_bf16_generation(rng)
        b = random_all_bf16_generation(rng)
        c = random_all_bf16_generation(rng)

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

# Write the expected value of given vectors after fma operation
def write_vector_results_fma(path, vectors):
    with open(path, "w") as f:
        for a, b, c in vectors:

            expected_result = reference_model.fma_bf16_ref(a, b, c)

            # Writes input floats and their corresponding expected value
            f.write(f"{a:04x} {b:04x} {c:04x} {expected_result:04x}\n")
    print(f"{path}: {len(vectors)} vectors")

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

def main():
    rng = random.Random(SEED)
    write_vector_results_fma("tb/vectors/vec_random_fma.txt",  fma_random_vectors(rng, FMA_RANDOM_COUNT))
    write_vector_results_fma("tb/vectors/vec_special_fma.txt", fma_special_vectors())
    write_vector_results_multiplier("tb/vectors/vec_multiplier_random.txt", multiplier_random_vectors(rng, MUL_RANDOM_COUNT))
    write_vector_results_multiplier("tb/vectors/vec_multiplier_exhaustive.txt", multiplier_exhaustive_vectors())
    write_vector_results_aligner("tb/vectors/vec_aligner_random.txt",
                                aligner_random_vectors(rng, ALIGNER_RANDOM_COUNT))
    write_vector_results_aligner("tb/vectors/vec_aligner_edge.txt",
                                aligner_edge_shift_vectors())
    write_vector_results_addsub("tb/vectors/vec_addsub_random.txt", addsub_random_vectors(rng, ADDSUB_RANDOM_COUNT))
    write_vector_results_normalizer("tb/vectors/vec_normalizer_random.txt", normalizer_random_vectors(rng, NORMALIZER_RANDOM_COUNT))
    
if __name__ == "__main__":
    main()
