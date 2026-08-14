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
    vectors.append()
    # Signed zero and DAZ

    # Cancellation

    # Rounding boundaries

    return vectors

# Write the expected value of given vectors after fma operation
def write_vector_results_fma(path, vectors):
    with open(path, "w") as f:
        for a, b, c in vectors:

            expected_result = reference_model.fma_bf16_ref(a, b, c)

            # Writes input floats and their corresponding expected value
            f.write(f"{a:04x} {b:04x} {c:04x} {expected_result:04x}\n")
    print(f"{path}: {len(vectors)} vectors")
