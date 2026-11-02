# Linear Exact Repair Schemes for Reed–Muller Codes

## Gröbner Basis Approach with One Fixed Entry per Helper Vector

This directory contains a distributed Magma implementation for searching for **linear exact repair schemes (LERSs)** for generalized Reed–Muller codes using a Gröbner basis approach.

The implementation fixes the first entry of each helper vector in a rank-one factorization of the repair matrix. Candidate assignments are enumerated, filtered using the minimum distance of the dual code, and processed through a manager–worker architecture. Each worker constructs and solves a polynomial system and saves its results for subsequent postprocessing.

## 1. Mathematical Background

Let $K=\mathbb{F}_q$, $F=\mathbb{F}_{q^t}$, and $Q=q^t$. Consider the generalized Reed–Muller code $C$ with parameters $(r,m)$ obtained by evaluating polynomials of total degree at most $r$ on a selected subset of $F^m$. For the full-length code, the support is $F^m$ and $n=(q^t)^m$.

We study linear exact repair of the first coordinate using the remaining $n-1$ coordinates. A repair scheme is represented by $t$ dual codewords whose values at the erased coordinate form a basis of $F$ over $K$. Writing their coordinates over $K$ gives a block matrix

$$
A=[I_t\mid A_2\mid\cdots\mid A_n],
$$

where $I_t$ normalizes the erased coordinate and each helper block has rank at most one over $K$. The implementation parameterizes the helper blocks as

$$
A_j=u_jv_j,\qquad u_j\in K^{t\times 1},\quad v_j\in K^{1\times t}.
$$

Each helper block therefore requires at most one base-field symbol to be downloaded. Zero helper blocks are permitted, but the reviewed solver does **not** explicitly prescribe `l` zero blocks.

### Fixing the First Entry

For every helper $j=2,\ldots,n$, the first entry of $u_j$ is fixed:

$$
u_j=(a_j,u_{j,2},\ldots,u_{j,t})^\top,\qquad a_j\in K.
$$

The remaining $t-1$ entries of $u_j$ and all $t$ entries of $v_j$ are polynomial unknowns. Thus, each task fixes $n-1$ entries and leaves $(n-1)(2t-1)$ variables. There are $q^{n-1}$ possible assignments before filtering.

## 2. Polynomial-System Construction

The main solver is defined in `GB_function_variable_support`:

```magma
SetOfAllDualCodewords(q, t, r, m, n, s, list);
```

Here `list` contains the $n-1$ fixed first entries of the helper vectors. The solver returns a Boolean, distinct repair matrices over $F$, and the variety of the polynomial system.

### Evaluation Support and Generator Matrix

The solver enumerates the elements of $F$ and then the points of $F^m$. If `s = 0`, it uses the first `n` points; otherwise, when `n < Q^m`, it excludes index `s` from the first `n+1` points. When `n = Q^m`, it uses the full evaluation support regardless of `s`.

The implementation enumerates exponent vectors with total degree at most $r$, evaluates the associated monomials, and constructs a matrix $G_F$ over $F$. The current enumeration does not explicitly impose the reduced exponent bounds $e_i\le Q-1$, so some rows can be redundant.

### Dual-Code Orthogonality

The symbolic repair matrix must satisfy

$$
G_F H^\top=0,
$$

where $H\in F^{t\times n}$ is obtained by grouping the base-field coordinates of $A$ into extension-field elements. The solver expands these conditions into polynomial equations over $K$ using a multiplication table for the chosen basis of $F/K$.

Every polynomial variable is also constrained to lie in $K$ through

$$x^q-x=0.$$

### Resultants and Gröbner Bases

The solver constructs a polynomial ring with an elimination ordering. For up to 500 of the $v$-variables, it looks for pairs of equations linear in that variable and appends their resultant as an additional polynomial consequence.

It constructs the resulting ideal, checks its dimension, and computes its variety only when the ideal is zero-dimensional. It evaluates the symbolic matrix at each solution, removes duplicate base-field matrices, converts the matrices to $F$, and verifies dual-code orthogonality.

A `false` return value does **not** always prove that no repair scheme exists: the solver also returns `false` when the ideal is positive-dimensional.

## 3. Distributed Computation

The implementation uses Magma's `DistributedManager` and `MonitoredDistributedWorker` interfaces. The manager distributes integer task identifiers; workers convert them into base-$q$ vectors of length $n-1$ and call the solver.

```text
run_manager_worker.sh
         |
         v
     manager.mag
         |
         | Enumerate assignments and apply distance filter
         | Group accepted identifiers into batches
         v
  DistributedManager
         |
         v
      worker.mag  (multiple worker processes)
         |
         v
GB_function_variable_support
         |
         v
  Per-task results and timing files
         |
         v
    Postprocessing
```

### Candidate Filtering

For the **full-length** generalized Reed–Muller code, the dual has order

$$r_{\mathrm{dual}}=m(Q-1)-r-1.$$

Write $r_{\mathrm{dual}}=a(Q-1)+b$ with $0\le b<Q-1$. Its minimum distance is

$$d(C^\perp)=(Q-b)Q^{m-a-1}.$$

The manager accepts a fixed-entry assignment `vec` only if the number of zeros is smaller than $n-d(C^\perp).$ This is the filter implemented in `manager.mag`. The stated dual-distance formula is specific to the full-length code and must not be assumed unchanged for a modified evaluation support.

### Batching and Parallelism

The manager uses batches of at most $2^{14}=16{,}384$ accepted task identifiers. Each batch is passed to `DistributedManager` on the configured local socket. Worker count, Slurm resource requests, and launch details are determined by the shell scripts.

## 4. Repository Structure

```text
Repair_Scheme_Reed_Mueller_Code/
├── GB_function_variable_support
├── parameters.mag
├── manager.mag
├── worker.mag
├── postprocess.mag
├── run_manager_worker.sh
├── start_worker.sh
├── run_postprocess.sh
└── README.md
```

| File | Description |
|---|---|
| `GB_function_variable_support` | Constructs and solves the polynomial system for a fixed assignment |
| `parameters.mag` | Defines field, code, support, and communication parameters |
| `manager.mag` | Enumerates, filters, batches, and distributes task identifiers |
| `worker.mag` | Runs the solver and saves per-task outputs |
| `start_worker.sh` | Worker launcher (exact behavior to be checked against the script) |
| `run_manager_worker.sh` | Distributed job launcher (exact Slurm settings to be checked) |
| `postprocess.mag` | Postprocessing implementation (outputs to be verified) |
| `run_postprocess.sh` | Postprocessing launcher (arguments to be verified) |
| `README.md` | Mathematical and computational documentation |

## 5. Configuration

The parameters are defined in `parameters.mag`:

```magma
q := 2;         // Base field size
t := 2;         // Extension degree
r := 4;         // Maximum polynomial order
m := 3;         // Number of polynomial variables
n := 64;        // Evaluation length
s := 0;         // Evaluation-support selection
port_num := 40000;
```

For this configuration, $Q=4$ and $n=4^3=64$, so the full support $F^3$ is used. The dual order is

$$r_{\mathrm{dual}}=3(4-1)-4-1=4.$$

Writing $4=1\cdot3+1$ gives $d(C^\perp)=3\cdot4=12$. Consequently, the manager retains assignments with at most $64-12=52$ zeros. The initial enumeration has $2^{63}$ candidates, which is computationally enormous even before solving any polynomial systems.

## 6. Requirements

- Magma, including distributed computation support
- Bash
- Slurm, if using the provided cluster submission scripts
- A filesystem accessible to the relevant processes

The reviewed Magma files use local socket communication (`localhost`) and relative `load` paths. Run them from the directory containing the source files unless the launch scripts explicitly change directories.

## 7. Running the Computation

Edit `parameters.mag` and, from `Repair_Scheme_Reed_Mueller_Code/`, submit the job with:

```bash
sbatch run_manager_worker.sh
```

The manager enumerates candidate assignments, filters them, and dispatches accepted task identifiers to workers. Before launching a large experiment, test a much smaller configuration: the current parameters require iterating over $2^{63}$ candidate identifiers.

The exact job-directory naming, worker-count environment variables, and Slurm CPU allocation must be confirmed from `run_manager_worker.sh` and `start_worker.sh`.

## 8. Output Files

For each task, `worker.mag` creates a directory named `Task_<worker_id>_<task_number>` beneath the configured job folder. It writes:

```text
<job_folder>/
└── Task_<worker_id>_<task_number>/
    ├── objects.mag
    ├── output.mag
    ├── data_<worker_id>_<task_number>.txt
    └── status_<worker_id>_<task_number>.txt
```

| File | Contents |
|---|---|
| `objects.mag` | Serialized task number, fixed-entry vector, polynomial solutions, and distinct repair matrices, in that order |
| `output.mag` | Human-readable task number, input vector, and solutions |
| `data_*.txt` | Elapsed time for the task |
| `status_*.txt` | `started` or `finished` |

The worker opens `objects.mag` and `output.mag` in append mode. Re-running a task in the same directory may therefore append duplicate records. Additional job-level logs and statistics depend on the launcher scripts.

## 9. Postprocessing

The directory contains `postprocess.mag` and `run_postprocess.sh` for collecting the results of distributed computations. Their exact input arguments, aggregation behavior, and generated filenames have **not yet been verified** against the Reed–Muller versions of these scripts.

Do not assume that the Reed–Solomon postprocessing commands, summary-table format, or deduplication behavior apply unchanged. Document the precise invocation after reviewing these two files.

## 10. Research Context

This implementation supports computational investigations of linear exact repair schemes for generalized Reed–Muller codes. The method translates the existence of suitable dual codewords into algebraic constraints, uses fixed helper-vector entries to reduce the number of polynomial unknowns, and distributes independent assignments across workers.

It belongs to a broader research effort studying repair schemes for linear codes and their connections to information leakage in secret-sharing schemes.

## 11. Implementation Notes

- The current strategy fixes **one entry in each of the $n-1$ helper vectors**
- The minimum-distance filter assumes the full-length generalized Reed–Muller dual-distance formula.

The mathematical algorithms are implemented in Magma, while shell scripts handle process launching and result collection.
