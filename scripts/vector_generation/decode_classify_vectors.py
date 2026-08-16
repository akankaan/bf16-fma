import reference_model

from .vector_common import random_finite_bf16_generation

SEED = 1

def decode_classify_random_vectors(rng, n):

    vectors = []

    for i in range(0, n):
        
        a = random_finite_bf16_generation(rng)
        b = random_finite_bf16_generation(rng)
        c = random_finite_bf16_generation(rng)

        vectors.append((a, b, c))

    return vectors

# Write the expected outputs of the decode_classify unit for the given vectors
def write_vector_results_decode_classify(path, vectors):
    with open(path, "w") as f:
        for a, b, c in vectors:
            (a_sign,     b_sign,     c_sign,
             a_zero,     b_zero,     c_zero,
             a_exponent, b_exponent, c_exponent,
             a_fraction, b_fraction, c_fraction,
             bypass_arithmetic,      fma_flag_result) = reference_model.decode_classify_ref(a, b, c)

            # Write inputs followed by every decode_classify output
            line = (f"{a:04x} {b:04x} {c:04x} "
                    f"{a_sign:01x} {b_sign:01x} {c_sign:01x} "
                    f"{a_zero:01x} {b_zero:01x} {c_zero:01x} "
                    f"{a_exponent:02x} {b_exponent:02x} {c_exponent:02x} "
                    f"{a_fraction:02x} {b_fraction:02x} {c_fraction:02x} "
                    f"{bypass_arithmetic:01x} {fma_flag_result:04x}")

            f.write(line + "\n")

    print(f"{path}: {len(vectors)} vectors")
