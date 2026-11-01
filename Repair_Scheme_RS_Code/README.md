# Linear Exact Repair Schemes for Reed–Solomon Codes

This directory contains Magma implementations for the computational investigation of **linear exact repair schemes (LERSs)** for Reed–Solomon codes via Gröbner approach.

The implementations explore different variable-fixing strategies to reduce the complexity of the polynomial systems.

The computations are designed for parallel execution using Magma's distributed manager–worker architecture and the Slurm workload manager.

## 1. Mathematical Background

Let $K=\mathbb{F}_q$ and $F=\mathbb{F}_{q^t}$, and consider a $[n,k]$ Reed–Solomon code $C$ over $F$.
We study linear exact repair of a code coordinate using information downloaded from the remaining $n-1$ coordinates.
A linear exact repair scheme can be described using $t$ dual codewords, represented by a matrix

$$
H\in F^{t\times n}.
$$

The corresponding base-field representation consists of $t\times t$ blocks,

$$
A=[I_t\mid A_2\mid\cdots\mid A_n],
$$

where $I_t$ is the normalized block corresponding to the erased coordinate.

To construct repair schemes with at most one base-field symbol downloaded from each helper coordinate, we impose that the rank for each helper block is at most 1. These blocks can be parameterized as

$$
A_j=u_jv_j,
\qquad
u_j\in K^{t\times 1},
\quad
v_j\in K^{1\times t}.
$$

The resulting dual-code orthogonality conditions are expressed as polynomial equations over $K$. The implementations use Gröbner basis techniques to solve these polynomial systems.

## 2. Variable-Fixing Strategies

The repository contains two approaches for reducing the number of polynomial variables.

### Approach 1: Fixing the First Entry

**Directory:** `Fixing_first_coordinate_u_{i,1}_ n-1_values/`

The first entry of each helper vector $u_j$ is fixed:

$$
u_j=
\begin{pmatrix}
a_j\\
u_{j,2}\\
\vdots\\
u_{j,t}
\end{pmatrix},
\qquad a_j\in K.
$$

For $n-1-l$ helper blocks not prescribed as zero, this gives $n-1-l$ fixed entries and an initial search space of $q^{n-1-l}$ assignments. This approach leaves relatively many polynomial variables but requires fewer fixed-entry assignments. See the [README for the first-entry strategy](Fixing_first_coordinate_u_%7Bi%2C1%7D_%20n-1_values/README.md).

### Approach 2: Fixing the First Two Entries

**Directory:** `Fixing_first_two_coordinates_u_{i,1:2}_2n-1_values/`

The first two entries of each helper vector $u_j$ are fixed:

$$
u_j=
\begin{pmatrix}
a_j\\
b_j\\
u_{j,3}\\
\vdots\\
u_{j,t}
\end{pmatrix},
\qquad a_j,b_j\in K.
$$

For $n-1-l$ helper blocks not prescribed as zero, this gives $2(n-1-l)$ fixed entries and an initial search space of $q^{2(n-1-l)}$ assignments. This approach reduces the number of polynomial variables per task at the cost of a larger assignment space.

See the [README for the first-two-entries strategy](Fixing_first_two_coordinates_u_%7Bi%2C1%3A2%7D_2n-1_values/README.md).

## 3. Comparison of the Approaches

| Approach | Fixed entries per helper vector | Initial assignments |
|---|---|---|
| First-entry fixing | 1 | $q^{n-1-l}$ |
| First-two-entries fixing | 2 | $q^{2(n-1-l)}$ |

Here, $l$ denotes the number of helper blocks prescribed to be zero. Fixing more variables reduces the number of unknowns in each polynomial system but increases the number of assignments that must be considered. The computational efficiency of each approach depends on the code parameters, the number of assignments retained after filtering, and the complexity of the resulting polynomial systems.

## 4. Polynomial-System Construction

Let $G\in F^{k\times n}$ be the Reed–Solomon generator matrix. The dual-code orthogonality condition is

$$
GH^\top=0.
$$

Using a basis of $F$ over $K$, the equations are expanded into polynomial equations over $K$. The field equations

$$
x^q-x=0
$$

are included to ensure that polynomial variables take values in $K$. The resulting polynomial systems are investigated using Magma's algebraic computation functionality. 

## 5. Repository Structure

```text
Repair_Scheme_RS_Code/
├── Fixing_first_coordinate_u_{i,1}_ n-1_values/
│   └── README.md
├── Fixing_first_two_coordinates_u_{i,1:2}_2n-1_values/
│   └── README.md
└── README.md
```

Each approach is organized into its own directory and include scripts for configuring, distributing, solving, and postprocessing computations.

## 6. Distributed Computation

The implementations use Magma's distributed computation functionality to process fixed-variable assignments in parallel.

The general workflow is:

```text
       Code parameters
              |
              v
    Variable-fixing strategy
              |
              v
    Candidate enumeration
              |
              v
    Minimum-distance filtering
              |
              v
      Task distribution
              |
       +------+------+
       |      |      |
       v      v      v
    Worker  Worker  Worker
       |      |      |
       +------+------+
              |
              v
    Polynomial-system solving
              |
              v
       Task results
              |
              v
       Postprocessing
              |
              v
    Unique repair schemes
```

Individual task results are stored separately, allowing computations to be analyzed and summarized after execution.

Detailed instructions for running each implementation are provided in the corresponding directory.

## 7. Requirements

- Magma computational algebra system
- Bash
- Slurm workload manager for cluster execution
- A suitable shared filesystem and computing environment

The scripts were developed for research computations and may require adjustments to the cluster configuration, resource allocation, or filesystem paths.

## 8. Research Context

This repository supports the systematic derivation of linear exact repair schemes for Reed–Solomon codes.
The main objective is to identify repair schemes through algebraic constraints on collections of dual codewords and to investigate how different variable-fixing strategies affect the complexity of finding such schemes.
These computations form part of a broader research project studying linear exact repair schemes, their algebraic properties, and their connections to information leakage in secret-sharing schemes.

## 9. Implementation Notes

The implementations are intended for research and experimentation rather than as general-purpose software packages.

In particular:

- Candidate filtering can reduce the number of systems that need to be solved.
- Computational complexity depends strongly on the Reed–Solomon code parameters.

For implementation-specific details, refer to the README and source files in each approach directory.