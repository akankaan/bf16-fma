# Vector generation for the validation of the Bfloat16 FMA (Fused Multiply Add) unit

# Author: Kaan Akan
# Date  : July 24, 2026

import random

from vector_generation import addsub_vectors
from vector_generation import aligner_vectors
from vector_generation import fma_vectors
from vector_generation import multiplier_vectors
from vector_generation import normalizer_vectors
from vector_generation import rounder_vectors

FMA_RANDOM_COUNT        = 100000
MUL_RANDOM_COUNT        = 100000
ALIGNER_RANDOM_COUNT    = 100000
ADDSUB_RANDOM_COUNT     = 100000
NORMALIZER_RANDOM_COUNT = 100000
ROUNDER_RANDOM_COUNT    = 100000

def main():
    fma_rng        = random.Random(fma_vectors.SEED)
    multiplier_rng = random.Random(multiplier_vectors.SEED)
    aligner_rng    = random.Random(aligner_vectors.SEED)
    addsub_rng     = random.Random(addsub_vectors.SEED)
    normalizer_rng = random.Random(normalizer_vectors.SEED)
    rounder_rng    = random.Random(rounder_vectors.SEED)

    fma_vectors.write_vector_results_fma("tb/vectors/vec_random_fma.txt",
                                         fma_vectors.fma_random_vectors(fma_rng, FMA_RANDOM_COUNT))
    fma_vectors.write_vector_results_fma("tb/vectors/vec_special_fma.txt",
                                         fma_vectors.fma_special_vectors())
    fma_vectors.write_vector_results_fma("tb/vectors/vec_directed_fma.txt",
                                             fma_vectors.fma_directed_vectors())
    
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
        "tb/vectors/vec_aligner_edge.txt",
        aligner_vectors.aligner_edge_shift_vectors())
    
    addsub_vectors.write_vector_results_addsub(
        "tb/vectors/vec_addsub_random.txt",
        addsub_vectors.addsub_random_vectors(addsub_rng, ADDSUB_RANDOM_COUNT))
    
    normalizer_vectors.write_vector_results_normalizer(
        "tb/vectors/vec_normalizer_random.txt",
        normalizer_vectors.normalizer_random_vectors(normalizer_rng, NORMALIZER_RANDOM_COUNT))
    
    rounder_vectors.write_vector_results_rounder(
        "tb/vectors/vec_rounder_random.txt",
        rounder_vectors.rounder_random_vectors(rounder_rng, ROUNDER_RANDOM_COUNT))

if __name__ == "__main__":
    main()
