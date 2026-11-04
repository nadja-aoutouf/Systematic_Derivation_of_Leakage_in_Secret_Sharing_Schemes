# Linear Exact Repair Schemes for Tamo–Barg Codes

## Hybrid Approach with Two Fixed Entries per Helper Vector

This directory contains a distributed Magma implementation for searching for **linear exact repair schemes (LERSs)** for Tamo–Barg codes via a Gröbner basis approach.

The approach reduces the number of unknowns by fixing the first two entries of each helper vector in a rank-one factorization of the repair matrix. Candidate assignments are enumerated, filtered, and processed in parallel using a manager–worker architecture.

The implementation supports computations on a Slurm cluster and includes scripts for collecting, deduplicating, and summarizing the resulting repair schemes.

## 1. Mathematical Background

Let $K=\mathbb{F}_q$ and $F=\mathbb{F}_{q^t}$, and consider an $[n,k]$ linear evaluation code $C$ over $F$ constructed using a Tamo–Barg polynomial exponent set with locality parameter $r$.

The generator matrix is constructed by evaluating monomials whose exponents are selected from

$$
E=\{j(r+1)+i:j\geq 0,\ 0\leq i<r\},
$$

truncated to its first $k$ elements.

The implementation evaluates these monomials at consecutive powers of a primitive element of $F$. For the resulting code to have the intended Tamo–Barg locality structure, the evaluation points must admit an appropriate partition into local repair groups.

We study linear exact repair of a code coordinate $s$ using information downloaded from the remaining $n-1$ coordinates. A repair scheme can be described using $t$ dual codewords, represented as the rows of a matrix

$$
H\in F^{t\times n}.
$$

The corresponding base-field representation consists of $t\times t$ blocks,

$$
A=[A_1\mid A_2\mid\cdots\mid A_n],
$$

where:

- $A_1=I_t$ is the normalized block corresponding to the erased coordinate, after reordering the evaluation points.
- $l$ helper blocks are prescribed to be zero.
- Every remaining helper block has rank at most one over $K$.

Each remaining helper block is parameterized as

$$
A_j=u_jv_j,
\qquad
u_j\in K^{t\times1},
\quad
v_j\in K^{1\times t}.
$$

This rank-one structure ensures that each corresponding helper contributes at most one base-field symbol to the repair process.

### Fixing the First Two Entries

To reduce the number of polynomial variables, the first two entries of every remaining helper vector $u_j$ are fixed:

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

The remaining $t-2$ entries of $u_j$, together with all $t$ entries of $v_j$, are treated as polynomial variables.

For $n-1-l$ remaining helper blocks, this gives $2(n-1-l)$ fixed entries, with $q^{2(n-1-l)}$ possible assignments before filtering.

Each polynomial system contains $(2t-2)(n-1-l)$ variables.

The manager enumerates the fixed-coordinate assignments, while the workers solve the corresponding polynomial systems.

### Selection of Zero Helper Positions

The implementation prescribes the first $l$ helper blocks, following the erased coordinate in the reordered evaluation set, to be zero.

Thus, the repair matrix has the form

$$
A=
[I_t\mid
\underbrace{0\mid\cdots\mid0}_{l\text{ blocks}}
\mid u_{l+2}v_{l+2}\mid\cdots\mid u_nv_n].
$$

Unlike the one-fixed-entry implementation, this version does not enumerate different subsets of zero helper positions.

Consequently, for $l>0$, the search considers only this prescribed placement of the zero blocks.

## 2. Polynomial-System Construction

The main function is

```magma
SetOfAllDualCodewords(q, t, k, n, r, s, l, list);
```

Here, `list` contains the $2(n-1-l)$ prescribed entries of the helper vectors, $r$ is the locality parameter, and $s$ specifies the erased coordinate using zero-based indexing.

The first half of `list` contains the first entries of the helper vectors, while the second half contains their second entries.

The function constructs a symbolic repair matrix and encodes the dual-code orthogonality conditions.

Let $G_{\mathrm{TB}}\in F^{k\times n}$ be the generator matrix. The required condition is

$$
G_{\mathrm{TB}}H^\top=0.
$$

The generator matrix is constructed using the evaluation points

$$
\alpha_1,\ldots,\alpha_n
$$

and the exponent set

$$
E=\{j(r+1)+i:j\geq0,\ 0\leq i<r\},
$$

truncated to its first $k$ elements.

The erased evaluation point is moved to the first position so that the corresponding repair block can be normalized to $I_t$.

Using a basis of $F$ over $K$, the extension-field orthogonality equations are expanded into polynomial equations over $K$.

To restrict the variables to the base field, the system also includes

$$
x^q-x=0
$$

for each polynomial variable $x$.

### Gröbner Bases

The implementation constructs an ideal from the dual-code orthogonality equations and the field equations.

The resulting ideal is analyzed using Magma's polynomial-system functionality. When the ideal is zero-dimensional, its variety is computed.

The resulting matrices are converted back into extension-field representations, and dual-code orthogonality is explicitly verified.

The solver returns:

- A Boolean indicating whether verified solutions were obtained.
- A sequence of distinct repair matrices over $F$.
- The corresponding polynomial-system solutions.

A `false` result does not necessarily establish mathematical nonexistence, since the solver also returns `false` for positive-dimensional ideals.

## 3. Distributed Computation

The implementation uses Magma's `DistributedManager` and `MonitoredDistributedWorker` interfaces.

The manager enumerates candidate assignments, filters them, and dispatches task identifiers to workers. Each worker reconstructs its assignment, solves the corresponding polynomial system, and saves its results.

```text
run_manager_worker.sh
         |
         v
     manager.mag
         |
         | Enumerate fixed-variable assignments
         | Apply candidate filtering
         | Divide accepted tasks into batches
         |
         v
   start_worker.sh
         |
         +----------+----------+----------+
         |          |          |          |
         v          v          v          v
      Worker 1   Worker 2   Worker 3   ...
         |          |          |
         +----------+----------+
                    |
                    v
       repair_scheme_solver.mag
                    |
                    v
        Polynomial-system solving
                    |
                    v
         Individual task results
                    |
                    v
            Postprocessing
```

### Candidate Filtering

The manager currently filters assignments using the conditions

$$
z_1+l\leq n-k-1,
\qquad
z_2+l\leq n-k-1,
$$

where $z_1$ and $z_2$ denote the numbers of zero entries in the first and second halves of the fixed-variable assignment, respectively.

These bounds were motivated by minimum-distance considerations. However, unlike Reed–Solomon codes, Tamo–Barg codes do not generally satisfy $d(C^\perp)=k+1$.

Moreover, a zero entry among the first two coordinates of $u_j$ does not necessarily imply that the corresponding helper block is zero.

Therefore, these filtering conditions require additional mathematical justification for the Tamo–Barg setting and should be regarded as restrictions of the implemented search.

### Batching and Parallelism

Accepted task identifiers are grouped into batches of at most $2^{14}=16384$ tasks.

The worker launcher starts multiple Magma processes, with the number controlled by `SLURM_CPUS_PER_TASK` (default: 1 outside Slurm).

The provided Slurm configuration requests 64 CPUs per task.

Each batch uses a separate communication port.

The number of worker processes should be chosen according to the available CPU and memory resources.

## 4. Repository Structure

```text
Fixing_first_two_coordinates_u_{i,1:2}_2n-1_values/
├── parameters.mag
├── repair_scheme_solver.mag
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
| `parameters.mag` | Defines code, repair, and communication parameters |
| `repair_scheme_solver.mag` | Constructs and solves the polynomial systems |
| `manager.mag` | Enumerates, filters, batches, and dispatches tasks |
| `worker.mag` | Executes individual computations and saves results |
| `start_worker.sh` | Launches multiple Magma worker processes |
| `run_manager_worker.sh` | Main Slurm job launcher |
| `postprocess.mag` | Aggregates solutions and generates a LaTeX summary |
| `run_postprocess.sh` | Prepares task lists and launches postprocessing |
| `README.md` | Documents the mathematical approach and execution workflow |

## 5. Configuration

The computation is configured through `parameters.mag`.

An example configuration is:

```magma
q := 2;    // Base field size
t := 4;    // Extension degree
k := 8;    // Code dimension
n := 15;   // Code length
r := 4;    // Locality parameter
s := 0;    // Erased coordinate (zero-based)
l := 0;    // Number of prescribed zero helper blocks

port_num := 21002; // Base communication port
```

This specifies a length-15, dimension-8 evaluation code over $\mathbb{F}_{16}$ using the Tamo–Barg exponent pattern with intended locality $r=4$.

For these parameters, $r+1=5$ divides $q^t-1=15$, allowing the nonzero field elements to be partitioned into three multiplicative cosets of size five.

The solver requires compatible field and code parameters. In particular, the chosen evaluation points and exponent space must define the intended Tamo–Barg code.

For this configuration, the manager considers a search space of $2^{28}=268\,435\,456$ candidate assignments before filtering. Each corresponding polynomial system contains $(2\cdot4-2)(15-1)=84$ variables.

This is a large search space, and a complete run may require substantial computational resources.

## 6. Requirements

- Magma computational algebra system, including its distributed computation functionality
- Bash
- Slurm workload manager for cluster execution
- A shared filesystem accessible to the manager and workers

The current scripts use local socket communication (`localhost`) and assume that the computation is launched from the directory containing the source files.

The Slurm partition and resource allocation may need to be adapted to the target cluster.

## 7. Running the Computation

From the `Fixing_first_two_coordinates_u_{i,1:2}_2n-1_values` directory, configure the parameters in `parameters.mag`.

Submit the distributed computation using:

```bash
sbatch run_manager_worker.sh
```

The script creates a job directory with a name of the form:

```text
Job_q2_t4_n15_k8_r4_s0_l0_YYYYMMDD_HHMMSS/
```

The directory contains worker logs, individual task results, and execution statistics.

The provided Slurm configuration requests 64 CPUs per task. The worker launcher uses `SLURM_CPUS_PER_TASK` to determine the number of Magma worker processes:

```bash
MAX="${SLURM_CPUS_PER_TASK:-1}"
```

To request a different number of CPUs, adjust the Slurm configuration or submit the job with an appropriate resource override, for example:

```bash
sbatch --cpus-per-task=32 run_manager_worker.sh
```

The worker count should be selected with the allocated resources in mind.

## 8. Output Files

Each task creates its own output directory:

```text
Job_q.../
├── data_job.txt
├── manager.consol
├── worker-1-port-*.mag
├── worker-1-port-*.log
├── ...
└── Task_<worker_id>_<task_number>/
    ├── objects.mag
    ├── output.mag
    ├── data_<worker_id>_<task_number>.txt
    └── status_<worker_id>_<task_number>.txt
```

The individual files contain:

| File | Contents |
|---|---|
| `objects.mag` | Serialized task identifier, fixed-variable assignment, polynomial-system solutions, and repair matrices |
| `output.mag` | Text representation of task inputs and solutions |
| `data_*.txt` | Computation time for the task |
| `status_*.txt` | Task execution status |
| `worker-*.log` | Individual worker logs |
| `data_job.txt` | Worker count and execution statistics |

The manager console output is redirected to `manager.consol` inside the job directory.

## 9. Postprocessing

After the distributed computation has finished, run:

```bash
bash run_postprocess.sh <job_directory>
```

For example:

```bash
bash run_postprocess.sh Job_q2_t4_n15_k8_r4_s0_l0_YYYYMMDD_HHMMSS
```

The postprocessing launcher identifies task directories containing serialized output and a completed status, and creates:

- `task_list.txt` — tasks selected for postprocessing.
- `task_uncompleted.txt` — task directories that do not satisfy the completion checks.

The Magma postprocessor then generates:

- `summary_table.tex` — a LaTeX table summarizing task identifiers, fixed-variable assignments, zero counts, and solution counts.
- `all_solutions.mag` — a serialized sequence of globally distinct repair matrices, created when solutions are found.

Duplicate repair matrices obtained from different fixed-coordinate assignments are removed during postprocessing.

The number of zeros reported in the summary table counts individual zero entries in the fixed-variable assignment, rather than helper blocks of rank zero.

The postprocessing launcher starts the Magma postprocessor in the background.

## 10. Research Context

This implementation supports the computational investigation of linear exact repair schemes for Tamo–Barg locally repairable codes.

The main objective is to identify repair schemes through algebraic constraints on collections of dual codewords. Fixing the first two entries of each helper vector reduces the number of unknowns in the polynomial systems, while distributed computation makes it possible to explore larger sets of parameter assignments.

Compared with fixing only one entry per helper vector, this strategy fixes more variables and therefore explores a larger space of prescribed assignments, but leaves fewer polynomial variables to be determined by the solver.

More precisely, the one-entry strategy introduces $(2t-1)(n-1-l)$ polynomial variables and $q^{n-1-l}$ fixed-coordinate assignments, whereas the two-entry strategy introduces $(2t-2)(n-1-l)$ polynomial variables and $q^{2(n-1-l)}$ fixed-coordinate assignments. The two approaches therefore provide different tradeoffs between the complexity of individual polynomial systems and the number of tasks that must be processed.

The implementation forms part of a broader research project investigating linear exact repair schemes, their algebraic construction, and connections to information leakage in secret-sharing schemes.

## 11. Implementation Notes

The current implementation is designed for research computations rather than as a general-purpose software package.

In particular:

- The rank-one parametrization allows helper blocks of rank zero, so the actual repair bandwidth may be smaller than $n-1-l$.
- Computation time and memory usage depend strongly on the code parameters and resulting polynomial systems.
- The launch scripts assume a compatible Magma and Slurm environment.

The mathematical algorithms are implemented in Magma, while Bash scripts handle job orchestration and result collection.