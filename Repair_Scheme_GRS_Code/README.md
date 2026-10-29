# Repair Schemes for Generalized Reed–Solomon Codes

## Overview

This directory contains a Magma implementation of a computational method for investigating **linear exact repair schemes (LERSs)** for Reed–Solomon (RS) and generalized Reed–Solomon (GRS) codes.

The implementation derives all leakage functions that theoretically support a leakage attack for Massey secret sharing schemes, where partial information about of each share enable the reconstruction of the associated secret.

## Mathematical Approach

Let \(K=\mathbb F_q\) and \(F=\mathbb F_{q^t}\). We consider a full-length RS or GRS code of length \(n=q^t\) and dimension \(k\) over \(F\).

The algorithm constructs a repair matrix representing \(t\) dual codewords, that satisfy the following constraints:

1. At the repaired coordinate, the \(t\) symbols are linearly independent over \(K\).
2. At every helper coordinate, the corresponding symbols span a subspace of dimension at most one over \(K\).
3. The reconstructed codewords satisfy the dual-code orthogonality conditions.

These constraints are translated into polynomial equations over \(K\), together with finite-field equations. The resulting polynomial ideal is used to compute valid repair sets.

## Implementation

The implementation is written in **Magma Computational Algebra System**.

| File | Description |
|---|---|
| `src/grs_generator.m` | Constructs RS and GRS generator matrices |
| `src/repair_scheme_solver.m` | Solves the polynomial system and constructs all valid repair matrices|
| `examples/example_q2_t2_k2.m` | Demonstrates the algorithm over GF(4) |
| `tests/test_grs_generator.m` | Tests generator matrix dimensions and rank |

**Main functions**

- `SetOfAllDualCodewords(q, t, k, G_F)` — Constructs and solves the polynomial system.
- `RS_G_F(q, t, k)` — Constructs a Reed–Solomon generator matrix.
- `GRSGeneratorMatrix(q, t, k, multipliers)` — Constructs a generalized Reed–Solomon generator matrix.

## Testing

The repository includes tests for both the generator matrices and the repair scheme solver.

The solver tests verify that each computed repair matrix:
- Satisfies the dual-code orthogonality conditions.
- Has full rank over the base field at the repaired coordinate.
- Has rank at most one over the base field at each helper coordinate.

To run the tests, navigate to the `tests/` directory and execute:

```bash
magma test_grs_generator.m
magma test_repair_scheme_solver.m
```

The tests use small examples over \(\mathbb F_4\) to verify the mathematical properties of the computed repair schemes.

## Running the Example

From the `examples` directory, run:

```bash
magma example_q2_t2_k2.m
```

The example considers \(q=2\), \(t=2\), and \(k=2\), and compares RS codes with GRS codes using nontrivial column multipliers.

The output includes the generator matrices and the number of distinct solutions.

## Requirements

- Magma Computational Algebra System

## Research Context

This implementation supports our research on linear exact repair schemes and leakage attacks on Massey secret sharing schemes, including a systematic computational approach via Gröbner approach.

Unlike the implementations for other code families in this repository, this implementation does not currently incorporate the **hybrid approach** or **distributed computation using a manager–worker architecture**. However, both techniques can be integrated by adapting the corresponding implementations available for the other repair schemes, if needed.