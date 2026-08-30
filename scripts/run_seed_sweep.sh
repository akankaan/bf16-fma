#!/bin/bash

seed=${1:-1}

while true; do
    echo "Running seed $seed"

    python3 scripts/generate_vectors.py --seed "$seed" || break
    make test || break

    echo "Seed $seed passed"
    seed=$((seed + 1))
done

echo "Failed on seed $seed"