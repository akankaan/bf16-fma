# Vector generation for the validation of the Bfloat16 FMA (Fused Multiply Add) unit

# Author: Kaan Akan
# Date  : July 24, 2026

import random

from vector_generation import addsub_vectors
from vector_generation import aligner_vectors
from vector_generation import decode_classify_vectors
from vector_generation import fma_vectors
from vector_generation import multiplier_vectors
from vector_generation import normalizer_vectors
from vector_generation import rounder_vectors

FMA_RANDOM_COUNT             = 100000
DECODE_CLASSIFY_RANDOM_COUNT = 100000
MUL_RANDOM_COUNT             = 100000
ALIGNER_RANDOM_COUNT         = 100000
ADDSUB_RANDOM_COUNT          = 100000
NORMALIZER_RANDOM_COUNT      = 100000
ROUNDER_RANDOM_COUNT         = 100000

def main():
    fma_rng             = random.Random(fma_vectors.SEED)
    decode_classify_rng = random.Random(decode_classify_vectors.SEED)
    multiplier_rng      = random.Random(multiplier_vectors.SEED)
    aligner_rng         = random.Random(aligner_vectors.SEED)
    addsub_rng          = random.Random(addsub_vectors.SEED)
    normalizer_rng      = random.Random(normalizer_vectors.SEED)
    rounder_rng         = random.Random(rounder_vectors.SEED)

    fma_vectors.write_vector_results_fma("tb/vectors/vec_random_fma.txt",
                                         fma_vectors.fma_random_vectors(fma_rng, FMA_RANDOM_COUNT))
    fma_vectors.write_vector_results_fma("tb/vectors/vec_special_fma.txt",
                                         fma_vectors.fma_special_vectors())
    fma_vectors.write_vector_results_fma("tb/vectors/vec_directed_fma.txt",
                                             fma_vectors.fma_directed_vectors())

    decode_classify_vectors.write_vector_results_decode_classify(
        "tb/vectors/vec_decode_classify_random.txt",
        decode_classify_vectors.decode_classify_random_vectors(
            decode_classify_rng, DECODE_CLASSIFY_RANDOM_COUNT))
    
    multiplier_vectors.write_vector_results_multiplier(
        "tb/vectors/vec_multiplier_random.txt",
        multiplier_vectors.multiplier_random_vectors(multiplier_rng, MUL_RANDOM_COUNT))
    multiplier_vectors.write_vector_results_multiplier(
        "tb/vectors/vec_multiplier_exhaustive.txt",
        multiplier_vectors.multiplier_exhaustive_vectors())
    
    aligner_vectors.write_vector_results_aligner(
        "tb/vectors/vec_aligner_random.txt",
        aligner_vectors.aligner_random_vectors(aligner_rng, ALIGNER_RANDOM_COUNT))
    aligner_vectors.write_vector_results_aligner(
        "tb/vectors/vec_aligner_exhaustive_shift_sweep.txt",
        aligner_vectors.aligner_exhaustive_shift_sweep_vectors())
    aligner_vectors.write_vector_results_aligner(
        "tb/vectors/vec_aligner_directed.txt",
        aligner_vectors.aligner_directed_vectors())
    
    addsub_vectors.write_vector_results_addsub(
        "tb/vectors/vec_addsub_random.txt",
        addsub_vectors.addsub_random_vectors(addsub_rng, ADDSUB_RANDOM_COUNT))
    addsub_vectors.write_vector_results_addsub(
        "tb/vectors/vec_addsub_directed.txt",
        addsub_vectors.addsub_directed_vectors())
    
    normalizer_vectors.write_vector_results_normalizer(
        "tb/vectors/vec_normalizer_random.txt",
        normalizer_vectors.normalizer_random_vectors(normalizer_rng, NORMALIZER_RANDOM_COUNT))
    normalizer_vectors.write_vector_results_normalizer(
        "tb/vectors/vec_normalizer_directed.txt",
        normalizer_vectors.normalizer_directed_vectors())
    
    rounder_vectors.write_vector_results_rounder(
        "tb/vectors/vec_rounder_random.txt",
        rounder_vectors.rounder_random_vectors(rounder_rng, ROUNDER_RANDOM_COUNT))
    rounder_vectors.write_vector_results_rounder(
        "tb/vectors/vec_rounder_directed.txt",
        rounder_vectors.rounder_directed_vectors())

if __name__ == "__main__":
    main()
