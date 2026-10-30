# Linear Exact Repair Schemes for Reed–Solomon Codes

## Gröbner-Basis Approach with Two Fixed Entries per Helper Vector

This directory contains a distributed Magma implementation for searching for **linear exact repair schemes (LERSs)** for Reed–Solomon codes via Gröbner approach.

The approach reduces the number of unknowns by fixing the first two entries of each helper vector in a rank-one factorization of the repair matrix. Candidate assignments are enumerated, filtered using minimum-distance constraints, and processed in parallel using a manager–worker architecture.

The implementation supports computations on a Slurm cluster and includes scripts for collecting, deduplicating, and summarizing the resulting repair schemes.

## 1. Mathematical Background

Let $K=\mathbb{F}_q$ and $F=\mathbb{F}_{q^t}$, and consider an $[n,k]$ Reed–Solomon code $C$ over $F$.
We study linear exact repair of the first code coordinate using information downloaded from the remaining $n-1$ coordinates. A repair scheme can be described using $t$ dual codewords, represented as the rows of a matrix $H\in F^{t\times n}$.
The corresponding base-field representation consists of $t\times t$ blocks,
$$
A=[I_t\mid 0\mid\cdots\mid 0\mid A_{l+2}\mid\cdots\mid A_n],
$$
where:
- $I_t$ is the normalized block corresponding to the erased coordinate.
- The next $l$ blocks are prescribed to be zero.
- Every remaining helper block has rank at most one over $K$.
Each nonzero helper block is parameterized as $A_j=u_jv_j$, with
$$
u_j\in K^{t\times 1},
\qquad
v_j\in K^{1\times t}.
$$
This rank-one structure ensures that each corresponding helper contributes at most one base-field symbol to the repair process.


### Fixing the First Two Entries

To reduce the number of polynomial variables, the first two entries of every helper vector $u_j$ are fixed:
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
The remaining entries of $u_j$, together with all entries of $v_j$, are treated as polynomial variables.
For $n-1-l$ nonzero helper blocks, this gives $2(n-1-l)$ fixed entries, with $q^{2(n-1-l)}$ possible assignments before filtering.
The manager enumerates these assignments, while the workers solve the corresponding polynomial systems.

## 2. Polynomial-System Construction

The main function is
```magma
SetOfAllDualCodewords(q, t, k, n, l, list);
```
It constructs a symbolic repair matrix and encodes the dual-code orthogonality conditions. Let $G\in F^{k\times n}$ be the Reed–Solomon generator matrix. The required condition is
$$
GH^\top=0.
$$
Using a basis of $F$ over $K$, these extension-field equations are expanded into polynomial equations over $K$. To restrict the variables to the base field, the system also includes
$$
x^q-x=0
$$
for each polynomial variable $x$.

### Resultants and Gröbner bases

The implementation uses a polynomial ring with an elimination ordering and introduces additional resultant equations for selected variables.

The resulting ideal is analyzed using Magma's polynomial-system functionality. When the ideal is zero-dimensional, its variety is computed.

The resulting matrices are converted back into extension-field representations, and dual-code orthogonality is explicitly verified.

The solver returns:

- A Boolean indicating whether verified solutions were obtained.
- A sequence of distinct repair matrices over $F$.
- The variety of the polynomial system.

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
         | Apply minimum-distance filtering
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

### Candidate filtering


For an $[n,k]$ Reed–Solomon code, the dual code has minimum distance $d(C^\perp)=k+1$. Therefore, a nonzero dual codeword has at most $n-k-1$ zero coordinates. The manager uses this necessary condition to filter candidate assignments before dispatching them.

### Batching and parallelism

Accepted task identifiers are grouped into batches of at most $2^{13}=8192$ tasks.
The worker launcher starts multiple Magma processes, with the number controlled by the environment variable `MAX` (default: 256).
Each batch uses a separate communication port.
The number of worker processes should be chosen according to the available CPU and memory resources.

## 4. Repository Structure

```text
fixing_first_two_coordinates/
├── parameters.mag
├── repair_scheme_solver.mag
├── manager.mag
├── worker.mag
├── postprocess.mag
├── run_manager_worker.sh
├── start_worker.sh
└── run_postprocess.sh
```

| File | Description |
|---|---|
| `parameters.mag` | Defines code, repair, and communication parameters |
| `repair_scheme_solver.mag` | Constructs and solves the polynomial system |
| `manager.mag` | Enumerates, filters, batches, and dispatches tasks |
| `worker.mag` | Executes individual computations and saves results |
| `start_worker.sh` | Launches multiple Magma worker processes |
| `run_manager_worker.sh` | Main Slurm job launcher |
| `postprocess.mag` | Aggregates solutions and generates a LaTeX summary |
| `run_postprocess.sh` | Prepares task lists and launches postprocessing |

## 5. Configuration

The computation is configured through `parameters.mag`.

An example configuration is:

```magma
q := 2;    // Base field size
t := 4;    // Extension degree
k := 6;    // Code dimension
n := 14;   // Code length
l := 0;    // Number of prescribed zero helper blocks

port_num := 2003; // Base communication port
```


This defines a $[14,6]$ Reed–Solomon code over $\mathbb{F}_{16}$. The solver requires $t\geq 2$, a valid prime-power field size $q$, and a code length compatible with the available distinct evaluation points. For this configuration, the manager considers a search space of $2^{26}=67,108,864$ candidate assignments before filtering.

## 6. Requirements

- Magma computational algebra system, including its distributed computation functionality
- Bash
- Slurm workload manager for cluster execution
- A shared filesystem accessible to the manager and workers

The current scripts use local socket communication (`localhost`) and assume that the computation is launched from the directory containing the source files. The Slurm partition and resource allocation may need to be adapted to the target cluster.

## 7. Running the Computation

From the `fixing_first_two_coordinates` directory, configure the parameters in `parameters.mag`.
Submit the distributed computation using:

```bash
sbatch run_manager_worker.sh
```

The script creates a job directory with a name of the form:
```text
Job_q2_t4_n14_k6_l0_YYYYMMDD_HHMMSS/
```

The directory contains manager logs, worker logs, individual task results, and execution statistics.

To change the number of workers, supply the `MAX` environment variable through Slurm, for example:

```bash
sbatch --export=ALL,MAX=64 run_manager_worker.sh
```

The default Slurm configuration requests 64 CPUs per task. The worker count should be selected with the allocated resources in mind.

## 8. Output Files

Each task creates its own output directory:

```text
Job_q.../
├── manager.mag
├── manager.consol
├── data_job.txt
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
| `objects.mag` | Serialized task identifier, fixed-variable assignment, variety, and repair matrices |
| `output.mag` | Text representation of task inputs and solutions |
| `data_*.txt` | Computation time for the task |
| `status_*.txt` | Task execution status |
| `manager.consol` | Manager console output |
| `worker-*.log` | Individual worker logs |
| `data_job.txt` | Worker count and execution statistics |

## 9. Postprocessing

After the distributed computation has finished, run:

```bash
bash run_postprocess.sh <job_directory>
```

For example:

```bash
bash run_postprocess.sh Job_q2_t4_n14_k6_l0_YYYYMMDD_HHMMSS
```

The postprocessing launcher identifies task directories containing serialized output and creates:

- `task_list.txt` — tasks with an `objects.mag` file.
- `task_uncompleted.txt` — task directories without an `objects.mag` file.

The Magma postprocessor then generates:

- `summary_table.tex` — a LaTeX table summarizing task identifiers, fixed-variable assignments, zero counts, and solution counts.
- `all_solutions.mag` — a serialized sequence of globally distinct repair matrices, created when solutions are found.

Duplicate repair matrices obtained from different assignments are removed during postprocessing.

The existence of an `objects.mag` file is used as the current criterion for including a task in postprocessing; it does not independently verify successful task completion.

## 10. Research Context

This implementation supports the computational investigation of linear exact repair schemes for Reed–Solomon codes.
The main objective is to identify repair schemes through algebraic constraints on collections of dual codewords. Fixing selected entries of the helper vectors reduces the number of unknowns in the polynomial systems, while distributed computation makes it possible to explore larger sets of parameter assignments.
The implementation forms part of a broader research project investigating linear exact repair schemes, their algebraic construction, and connections to information leakage in secret-sharing schemes.

## 11. Implementation Notes

The current implementation is designed for research computations rather than as a general-purpose software package.
In particular:
- The solver processes a fixed assignment of helper-vector entries per task.
- Candidate filtering uses necessary minimum-distance conditions.
- Computation time and memory usage depend strongly on the code parameters and resulting polynomial systems.
- The launch scripts assume a compatible Magma and Slurm environment.

The mathematical algorithms are implemented in Magma, while Bash scripts handle job orchestration and result collection.