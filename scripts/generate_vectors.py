# Vector generation for the validation of the Bfloat16 FMA (Fused Multiply Add) unit

# Author: Kaan Akan
# Date  : July 24, 2026

import random
import reference_model

# Generate random vector that doesn't have special flags
def random_normal_bf16_generation(rng):
    return (rng.randint(0,1) << 15) | (rng.randint(1,254) << 7 ) | (rng.randint(0,127))

# Write the expected value of given vectors after operation
def write_vector_results(path, vectors):
    with open(path, "w") as f:
        for a, b, c in vectors:

            expected_result = reference_model.fma_bf16_ref(a, b, c)

            # Writes input floats and their corresponding expected value
            f.write(f"{a:04x} {b:04x} {c:04x} {expected_result:04x}\n")
    print(f"{path}: {len(vectors)} vectors")

rng = random.Random(1) # Using seed for reproducibility

# Add random vectors to random vector list
vector_generation_amount = 10000
rand_vectors = []

for i in range(0, vector_generation_amount ):
    rand_vectors.append((random_normal_bf16_generation(rng), 
                         random_normal_bf16_generation(rng), 
                         random_normal_bf16_generation(rng)))

# Add special vectors to random vector list
SPECIAL_VALUES = [0x7FC0, 0x7F80, 0xFF80, 0x0000, 0x8000, 0x0080, 0x7F7F, 0x3FC0]
special_vectors = []

for a in SPECIAL_VALUES:
    for b in SPECIAL_VALUES:
        for c in SPECIAL_VALUES:
            special_vectors.append((a, b, c))

# Calculate the result vectors and write to text file
write_vector_results("tb/vec_random.txt",  rand_vectors)
write_vector_results("tb/vec_special.txt", special_vectors)
