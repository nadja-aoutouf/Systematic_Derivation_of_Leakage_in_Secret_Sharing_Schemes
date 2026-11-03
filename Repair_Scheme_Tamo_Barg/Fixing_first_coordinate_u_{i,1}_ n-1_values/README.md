
# Linear Exact Repair Schemes for Tamo–Barg Codes

## Hybrid Approach with One Fixed Entry per Helper Vector

This directory contains a distributed Magma implementation for searching for **linear exact repair schemes (LERSs)** for Tamo–Barg codes via a Gröbner basis approach.

The approach reduces the number of unknowns by fixing the first entry of each helper vector in a rank-one factorization of the repair matrix. Candidate assignments are enumerated, filtered, and processed in parallel using a manager–worker architecture.

The implementation supports computations on a Slurm cluster and includes scripts for collecting, deduplicating, and summarizing the resulting repair schemes.

## 1. Mathematical Background

Let $K=\mathbb{F}_q$ and $F=\mathbb{F}_{q^t}$, and consider an $[n,k]$ Tamo–Barg code $C$ over $F$ with locality $r$.

The code is constructed by evaluating polynomials at points partitioned into local repair groups of size $r+1$. In this implementation, the evaluation points are selected from multiplicative cosets of a subgroup of $F^\times$ of order $r+1$.

We study linear exact repair of a code coordinate $e$ using information downloaded from the remaining $n-1$ coordinates. A repair scheme can be described using $t$ dual codewords, represented as the rows of a matrix

$$
H\in F^{t\times n}.
$$

The corresponding base-field representation consists of $t\times t$ blocks,

$$
A=[A_1\mid A_2\mid\cdots\mid A_n],
$$

where:

- $A_e=I_t$ is the normalized block corresponding to the erased coordinate.
- $l$ helper blocks are prescribed to be zero.
- Every remaining helper block has rank at most one over $K$.

Each remaining helper block is parameterized as

$$
A_j=u_jv_j,
\qquad
u_j\in K^{t\times 1},
\quad
v_j\in K^{1\times t}.
$$

This rank-one structure ensures that each corresponding helper contributes at most one base-field symbol to the repair process.

### Fixing the First Entry

To reduce the number of polynomial variables, the first entry of every remaining helper vector $u_j$ is fixed:

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

The remaining $t-1$ entries of $u_j$, together with all $t$ entries of $v_j$, are treated as polynomial variables.

For $n-1-l$ remaining helper blocks, this gives $n-1-l$ fixed entries, with $q^{n-1-l}$ possible assignments before filtering.

The manager enumerates these assignments, while the workers solve the corresponding polynomial systems.

### Selection of Zero Helper Positions

The implementation searches over subsets $S$ of $l$ helper positions satisfying

$$
S\subseteq\{1,\ldots,n\}\setminus\{e\},
\qquad |S|=l,
$$

and the additional condition

$$
\sum_{j\in S}\alpha_j=\alpha_e,
$$

where $\alpha_j$ denotes the evaluation point associated with coordinate $j$.

Only zero-position sets satisfying this condition are considered. This is an additional restriction of the implemented search procedure and is not a general necessary condition for linear exact repair schemes.

## 2. Polynomial-System Construction

The main function is

```magma
SetOfAllDualCodewords(q, t, k, n, r, l, list, e);
```

Here, `list` contains the $n-1-l$ prescribed first entries of the helper vectors, $r$ is the locality parameter, and $e$ specifies the erased coordinate.

The function constructs a symbolic repair matrix and encodes the dual-code orthogonality conditions.

Let $G_{\mathrm{TB}}\in F^{k\times n}$ be the Tamo–Barg generator matrix. The required condition is

$$
G_{\mathrm{TB}}H^\top=0.
$$

The generator matrix is constructed using evaluation points from multiplicative cosets and a polynomial exponent set of the form

$$
E=\{j(r+1)+i: j\ge 0,\ 0\le i<r\},
$$

truncated to its first $k$ elements.

Using a basis of $F$ over $K$, the extension-field orthogonality equations are expanded into polynomial equations over $K$. To restrict the variables to the base field, the system also includes $x^q-x=0$ for each polynomial variable $x$.

### Gröbner Bases

The implementation constructs an ideal from the dual-code orthogonality equations and the field equations.

Selected resultants are computed as an additional preprocessing step.

The resulting ideal is analyzed using Magma's polynomial-system functionality. When the ideal is zero-dimensional, its variety is computed.

The resulting matrices are converted back into extension-field representations, and dual-code orthogonality is explicitly verified.

The solver returns:

- A Boolean indicating whether verified solutions were obtained.
- A sequence of distinct repair matrices over $F$ for each zero-position configuration.
- The corresponding polynomial-system solutions.

A `false` result does not necessarily establish mathematical nonexistence, since the solver also returns `false` for positive-dimensional ideals or when no admissible zero-position set is found.

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

The manager currently filters assignments using the condition $z+l\le n-k-1,$ where $z$ denotes the number of zero entries in the fixed-variable assignment.

This bound was motivated by minimum-distance considerations. However, unlike Reed–Solomon codes, Tamo–Barg codes do not generally satisfy $d(C^\perp)=k+1$.

Moreover, a zero first entry of $u_j$ does not necessarily imply that the corresponding helper block is zero.

Therefore, this filtering condition requires additional mathematical justification for the Tamo–Barg setting and should be regarded as a restriction of the implemented search.

### Batching and Parallelism

Accepted task identifiers are grouped into batches of at most $2^{10}=1024$ tasks.

The worker launcher starts multiple Magma processes, with the number controlled by `SLURM_CPUS_PER_TASK` (default: 1 outside Slurm).

The provided Slurm configuration requests 64 CPUs per task.

Each batch uses a separate communication port.

The number of worker processes should be chosen according to the available CPU and memory resources.

## 4. Repository Structure

```text
Fixing_first_coordinate_u_{i,1}_ n-1_values/
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
q := 5;    // Base field size
t := 2;    // Extension degree
k := 15;   // Code dimension
n := 24;   // Code length
r := 5;    // Locality parameter
l := 4;    // Number of prescribed zero helper blocks
e := 1;    // Erased coordinate

port_num := 10101; // Base communication port
```

This defines a $[24,15]$ Tamo–Barg code over $\mathbb{F}_{25}$ with locality $r=5$.

The evaluation points are organized into four local repair groups of size $r+1=6$.

The solver requires compatible field and code parameters. In particular, the multiplicative-coset construction assumes $r+1\mid q^t-1$ and enough distinct cosets to construct the requested evaluation set. For this configuration, the manager considers a search space of $5^{19}=19\,073\,486\,328\,125$ candidate assignments before filtering.
This is a very large search space, and a complete run may require substantial computational resources.

## 6. Requirements

- Magma computational algebra system, including its distributed computation functionality
- Bash
- Slurm workload manager for cluster execution
- A shared filesystem accessible to the manager and workers

The current scripts use local socket communication (`localhost`) and assume that the computation is launched from the directory containing the source files.

The Slurm partition and resource allocation may need to be adapted to the target cluster.

## 7. Running the Computation

From the `Fixing_first_coordinate_u_{i,1}_ n-1_values` directory, configure the parameters in `parameters.mag`.

Submit the distributed computation using:

```bash
sbatch run_manager_worker.sh
```

The script creates a job directory with a name of the form:

```text
Job_q5_t2_n24_k15_r5_l4_e1_YYYYMMDD_HHMMSS/
```

The directory contains worker logs, individual task results, and execution statistics.

The provided Slurm configuration requests 64 CPUs per task. The worker launcher uses `SLURM_CPUS_PER_TASK` to determine the number of Magma worker processes.

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
├── worker-1.mag
├── worker-1.log
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
bash run_postprocess.sh Job_q5_t2_n24_k15_r5_l4_e1_YYYYMMDD_HHMMSS
```

The postprocessing launcher identifies task directories containing serialized output and creates:

- `task_list.txt` — tasks with an `objects.mag` file.
- `task_uncompleted.txt` — task directories without an `objects.mag` file.

The Magma postprocessor then generates:

- `summary_table.tex` — a LaTeX table summarizing task identifiers, fixed-variable assignments, zero counts, and solution counts.
- `all_solutions.mag` — a serialized sequence of globally distinct repair matrices, created when solutions are found.

Duplicate repair matrices obtained from different assignments or zero-position configurations are removed during postprocessing.

The existence of an `objects.mag` file is used as the current criterion for including a task in postprocessing; it does not independently verify successful task completion.

The postprocessing launcher starts the Magma postprocessor in the background.

## 10. Research Context

This implementation supports the computational investigation of linear exact repair schemes for Tamo–Barg locally repairable codes.

The main objective is to identify repair schemes through algebraic constraints on collections of dual codewords. Fixing the first entry of each helper vector reduces the number of unknowns in the polynomial systems, while distributed computation makes it possible to explore larger sets of parameter assignments.

Compared with fixing two entries per helper vector, this strategy fixes fewer variables and therefore explores a smaller space of prescribed assignments, but generally leaves more polynomial variables to be determined by the solver.

The implementation forms part of a broader research project investigating linear exact repair schemes, their algebraic construction, and connections to information leakage in secret-sharing schemes.

## 11. Implementation Notes

The current implementation is designed for research computations rather than as a general-purpose software package.

In particular:
- The search considers only zero-position sets satisfying the implemented evaluation-point condition.
- Computation time and memory usage depend strongly on the code parameters and resulting polynomial systems.
- The launch scripts assume a compatible Magma and Slurm environment.

The mathematical algorithms are implemented in Magma, while Bash scripts handle job orchestration and result collection.
