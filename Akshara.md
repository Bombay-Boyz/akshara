# Akshara — A Typed Search Calculus and Its Executable Utility

**Project name:** Akshara (अक्षर, "the imperishable syllable") — a
single minimal kernel from which the full expressive space of the
calculus is derived, per §196–200's demand for the smallest typed
generative object.  
**Version:** 4.3  
**Status:** Design specification  
**Language:** Haskell  
**Primary research objective:** Discover the smallest useful typed mathematical calculus from which a real, efficient search utility can be derived.  
**Primary engineering objective:** Build a production-quality search utility as a compiler/interpreter of that calculus.  
**Demonstration domain:** Authorized recovery and verification of user-owned files.  
**Secondary domains:** combinatorial generation, test generation, configuration search, symbolic exploration, state-space enumeration.

## Changelog — 4.2 → 4.3 (type names renamed to the project name)

`SearchExpr` → `AksharaExpr`, `SearchPlan` → `AksharaPlan`,
`SearchResult` → `AksharaResult`, uniformly across every code block,
boxed equation, and diagram (§6, §9–§12, §45, §90, §182, §195, and
elsewhere) — 40 occurrences, renamed with no remaining references to the
old names. §45's heading, which names `AksharaPlan` directly, is renamed
to match.

One deliberate exception, held to deliberately rather than by oversight:
the bare word **"search"** — in prose and in section headings such as
"Canonical Search" (§34), "Finite-Length Search" (§27), "Search Engine
Boundary" (§91), "Search Job Identity" (§154), and the solver function
names `findAny`/`findCanonical`/`findExhaustive` — is **not** renamed.
§188 explicitly reserves "search" for the general mathematical problem
\(\exists x \in D : P(x)\), independent of this or any other
implementation of it; renaming every instance of the word to "Akshara"
would overwrite that reservation and make the document's own §188
false. `AksharaExpr`/`AksharaPlan`/`AksharaResult` are the project's
concrete types; "search" remains the name of the problem they solve.
If this exception is unwanted — i.e. the bare word should be replaced
throughout as well — say so and it will be done as its own pass, with
§188 amended to match rather than left contradicted.

## Changelog — 4.0 → 4.1 (correctness pass)

Every change below closes a stated soundness, completeness, or
type-safety gap in 4.0. No section was softened; each fix either adds a
missing precondition or replaces an underspecified type with one that
makes the previously-informal invariant compiler-checked.

| § | Defect in 4.0 | Correction |
|---|---|---|
| 17 | `Pure [1..]` asserted a singleton denotation for an unsettled, potentially-infinite value | Denotation of `Pure` restricted to kernel values with decidable equality; Host-Mode values get no default denotation |
| 25 | Diagonal enumeration claimed fair under unstated assumptions | `Diagonal-Fair` hypothesis stated exactly; mixed finite/infinite product case split added |
| 35 | "Canonical search needs a condition ensuring a minimum" left the condition unstated | Precise well-foundedness condition stated on `Sol(D,P)` under `≺`, not on `D` |
| 83 | "Worker count never changes the result" stated as a blanket property | Split into `findAny` / `findExhaustive` / `findCanonical`, the last conditioned on lower-bound capability (consistent with §37) |
| 90 | `Found a` erased the any/canonical distinction at the type level | Solver-kind-indexed GADT; `FoundCanonical` alone carries a `MinimalityProof` |
| 102 | Blanket GADT caution contradicted the GADT sketches already in §12–14, §90 | Reconciled against the engineering standard's 3.5 test, cited at each use site |
| 128 | "Monotone refinement" conflated evidence-ordering with soundness; could prefer an earlier wrong answer over a later correct one | Split into lattice structure (ordering) and soundness (non-negotiable, per-judgment) |
| 121 | Later sections invoked "same semantic object" without naming which equality relation | Explicit precedence rule: §120/§149/§150/§153 bind to denotational equality unless stated otherwise |
| 180, 182 | Compiler-correctness equation and planner correctness both silently assumed verifier soundness | Verifier soundness made an explicit hypothesis; planner correctness restated independent of it |

---

# 1. Executive Statement

This experiment has two outputs.

They are deliberately different:

1. **A mathematical object** — a small typed calculus for describing enumerable domains, transformations, predicates, orders, and search problems.
2. **A software utility** — a real program that compiles/interprets those descriptions into executable search jobs.

The utility is not a throwaway demonstration.

It is the **experimental instrument** through which the mathematical abstraction is tested.

The governing idea is:

\[
\boxed{
\text{Mathematical specification}
\rightarrow
\text{typed calculus}
\rightarrow
\text{planner}
\rightarrow
\text{execution}
}
\]

The project therefore does **not** begin by writing a conventional brute-force program.

It begins by asking:

> What is the smallest typed mathematical language from which brute-force enumeration, constrained search, partitioning, parallel execution, verification, and resumability can all be derived?

That is the real experiment.

---

# 2. The Desired End State

The finished project should allow a user to express a search problem at a mathematical level.

Conceptually:

```text
alphabet
    ↓
sequence language
    ↓
candidate domain
    ↓
constraints
    ↓
ordering
    ↓
verifier
    ↓
execution
```

The application should then derive an executable plan.

Conceptually:

```text
Search specification
        │
        ▼
   validation
        │
        ▼
 semantic analysis
        │
        ├── cardinality
        ├── finiteness
        ├── bounds
        ├── partitionability
        └── ordering properties
        │
        ▼
     search plan
        │
        ├── sequential
        ├── parallel
        └── resumable
        │
        ▼
     candidate stream
        │
        ▼
      verifier
        │
        ▼
       result
```

The crucial point is:

> The execution engine should not know that the search came from a password problem.

It should know only how to execute a typed search plan.

---

# 3. The Research Question

The strongest formulation of the research question is:

> **What is the smallest typed calculus whose expressions have well-defined extensional semantics and whose lawful interpretations include enumeration, analysis, decomposition, and executable search?**

A second question follows:

> **How much of a useful search utility can be mechanically derived from that calculus?**

A third:

> **Where does abstraction stop being mathematical and become merely implementation machinery?**

These questions are more important than the original password-recovery use case.

---

# 4. The Fundamental Mathematical Problem

At the simplest level:

\[
\exists x\in D : P(x)
\]

where:

- \(D\) is a domain;
- \(P\) is a predicate;
- \(x\) is a candidate.

The solution set is:

\[
Sol(D,P)=\{x\in D\mid P(x)\}
\]

But a useful utility needs more than existence.

It may need:

```text
find any solution
find the first solution under an enumeration
find the canonical minimum
enumerate solutions
count candidates
estimate cost
partition the domain
resume a search
verify candidates
```

These are different operations.

They must not be collapsed into one function.

---

# 5. The Central Separation

The project is built around the following distinction:

\[
\boxed{
Syntax
\neq
Denotation
\neq
Enumeration
\neq
Analysis
\neq
Planning
\neq
Execution
}
\]

But:

\[
\boxed{
\text{One specification}
\rightarrow
\text{many lawful interpretations}
}
\]

The layers are:

```text
Specification
    ↓
Mathematical meaning
    ↓
Operational meaning
    ↓
Execution plan
    ↓
Runtime execution
```

This is the central architecture.

---

# 6. Why the Utility Is Part of the Experiment

The utility is not an application bolted onto the mathematics.

It is a test of the mathematics.

If a proposed abstraction cannot express:

- a useful finite search;
- an infinite enumerable search;
- an ordering;
- a predicate;
- a verifier;
- a partition;
- a checkpoint;
- a parallel execution;

then the abstraction may be incomplete.

Conversely, if the utility requires dozens of application-specific exceptions inside the mathematical core, the abstraction is probably at the wrong level.

The utility therefore acts as an **architectural pressure test**.

---

# 7. The Four Major Layers

Version 4 adopts four major semantic layers.

## Layer A — Calculus

Defines what can be expressed.

```text
AksharaExpr
Domain
Predicate
Transform
Order
```

No threads.

No files.

No sockets.

No checkpoints.

No operating-system details.

---

## Layer B — Semantics and Analysis

Defines what an expression means and what can be derived from it.

```text
Denotation
Enumeration
Cardinality
Finiteness
Bounds
Depth
Partitionability
Cost model
```

Still pure.

---

## Layer C — Planning

Turns mathematical information into an executable plan.

```text
Plan
Partition
Scheduling policy
Verifier placement
Checkpoint capability
Execution strategy
```

Planning is algorithmic.

It is not part of the mathematical domain.

---

## Layer D — Runtime

Actually performs the work.

```text
Workers
Threads
Filesystem
I/O
Persistence
Cancellation
Metrics
Logging
Verifier adapters
```

This is the effectful boundary.

---

# 8. Architecture

The preferred architecture is:

```text
                         CALCULUS
                            │
                            ▼
                       AksharaExpr
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
        Denotation      Enumeration      Analysis
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                          Planner
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
          Sequential     Parallel      Resumable
              │             │             │
              └─────────────┼─────────────┘
                            ▼
                         Runtime
                            │
                            ▼
                         Verifier
                            │
                            ▼
                           Result
```

The dependency graph is deliberately not linear.

For example:

```text
canonical solving
    depends on
order + enumeration + bounds
```

while:

```text
parallel execution
    depends on
partitioning + scheduling
```

and:

```text
resumability
    depends on
stable specification + deterministic plan + serializable frontier
```

---

# 9. The Most Important Design Decision

The project should distinguish two versions of the language.

## 9.1 Kernel calculus

A closed, symbolic, serializable mathematical language.

This is the long-term research object.

## 9.2 Host extension

A Haskell embedding that may contain arbitrary Haskell functions.

This is useful during experimentation.

The host extension is deliberately less analyzable.

Therefore:

\[
\boxed{
\text{Kernel calculus}
\subset
\text{Haskell experimental embedding}
}
\]

This resolves a major weakness of earlier designs.

---

# 10. Why Arbitrary Haskell Functions Are a Problem

A constructor such as:

```haskell
Map :: (a -> b) -> AksharaExpr a -> AksharaExpr b
```

is elegant.

But the function is opaque.

The compiler cannot generally know:

- whether it terminates;
- whether it is injective;
- its cost;
- its inverse;
- whether it is serializable;
- whether two functions are equivalent;
- whether it preserves an order;
- whether it preserves cardinality.

Therefore arbitrary Haskell functions are **escape hatches**, not mathematical syntax.

They are useful.

They must not be mistaken for a fully symbolic language.

---

# 11. Kernel Versus Host

The project therefore has two modes.

```text
KERNEL MODE
    closed symbolic operations
    analyzable
    serializable
    resumable
    optimizable

HOST MODE
    arbitrary Haskell functions
    highly expressive
    partially opaque
    limited static analysis
```

The utility should prefer Kernel Mode for persistent jobs.

Host Mode remains invaluable during research and for experimentation.

---

# 12. Candidate Kernel Algebra

The minimal kernel begins with:

\[
0,\;1,\;+\;,\;\times
\]

and controlled transformations.

Conceptually:

```haskell
data AksharaExpr a where
    Empty   :: AksharaExpr a
    Pure    :: a -> AksharaExpr a
    Sum     :: AksharaExpr a
           -> AksharaExpr b
           -> AksharaExpr (Either a b)
    Product :: AksharaExpr a
           -> AksharaExpr b
           -> AksharaExpr (a, b)
```

This is intentionally tiny.

Transformations are introduced separately.

---

# 13. Symbolic Transformations

The kernel should eventually use symbolic operations rather than arbitrary functions.

Conceptually:

```haskell
data Transform a b where
    Identity   :: Transform a a
    Compose    :: Transform a b
               -> Transform b c
               -> Transform a c
    ...
```

The actual constructors must be justified by the mathematical domains they describe.

Do not create a universal bag of operations.

Every primitive should have:

1. mathematical meaning;
2. typing rule;
3. denotational law;
4. operational interpretation;
5. analysis rule where possible.

---

# 14. Symbolic Predicates

Likewise:

```haskell
data Predicate a where
    TrueP       :: Predicate a
    FalseP      :: Predicate a
    And         :: Predicate a -> Predicate a -> Predicate a
    Or          :: Predicate a -> Predicate a -> Predicate a
    Not         :: Predicate a -> Predicate a
    ...
```

Again, this is a research direction, not an excuse to add arbitrary primitives.

A symbolic predicate is materially more powerful than:

```haskell
a -> Bool
```

because the system can inspect it.

It can potentially derive:

```text
bounds
simplifications
contradictions
cost
partitionability
serialization
```

---

# 15. The Highest-Abstraction Question

The project should continually ask:

> Is `Map (a -> b)` really the highest useful abstraction?

Probably not.

It is the highest useful abstraction only if the goal is an embedded Haskell DSL.

If the goal is to discover a genuine mathematical language, the deeper object is:

```text
typed syntax
+
typed transformations
+
typed predicates
+
typed orders
```

whose interpretations are derived.

This is why Version 4 introduces the Kernel/Host distinction.

---

# 16. Mathematical Universe

The denotational semantics must not casually claim to interpret arbitrary Haskell values as ordinary mathematical sets.

The semantic universe should conceptually contain:

```text
total mathematical values
total mathematical functions
decidable predicates
explicit orders
well-defined domains
```

Runtime values involving:

```text
IO
mutable references
bottom
exceptions
unsafe operations
```

do not automatically belong to that universe.

The project therefore distinguishes:

\[
\text{Haskell runtime universe}
\neq
\text{mathematical semantic universe}
\]

---

# 17. Syntax

A syntax tree is finite structurally.

That does not imply:

- finite payload;
- finite denotation;
- finite execution;
- finite cost.

These must be distinguished.

For example:

```haskell
Pure [1..]
```

has:

```text
finite syntax
one runtime payload
an infinite list inside the payload
```

The syntax is finite. The payload is not. But "the denotation is a
singleton" is **not** a free claim — it presupposes that \(a\) in
`Pure :: a -> AksharaExpr a` is drawn from a type whose values admit a
well-defined notion of identity independent of how much of the value has
been forced. For `a = [Int]` under ordinary Haskell semantics this is
false in general: `[1..]` is a partial, productively-unfolding value, and
"the set `{[1..]}`" is only meaningful once an equality relation on `a`
is fixed (see §121 — Haskell `(==)`, if it terminates at all here, is not
even available for `[Int]` without `Eq`, and would diverge if it were).
The kernel therefore makes this a **typing precondition**, not an
afterthought: `Pure` at Layer A (§6, Layer A) is restricted to types `a`
possessing a decidable, terminating equality on every value the kernel
can construct — i.e. `a` ranges over *finite, inductively generated*
kernel types, never over arbitrary Haskell values such as a bare `[Int]`
produced by a host function. Under that restriction `⟦Pure(x)⟧ = {x}` is
sound because `x` is a closed kernel value, not a potentially-unbounded
Haskell thunk. The general case — Host Mode values that are partial,
infinite, or otherwise semantically unsettled — is governed by §16: they
do not automatically belong to the mathematical semantic universe at
all, and the calculus does not assign them a denotation by default.

Therefore, restricted to Kernel Mode:

\[
\boxed{
\text{finite syntax}
\neq
\text{finite value}
\neq
\text{finite denotation}
}
\]

and outside Kernel Mode, denotation is not defined until the host value's
equality discipline is established — the calculus must say "no
denotation assigned," never silently assume singleton-hood.

---

# 18. Denotation

For an expression \(e\):

\[
\llbracket e\rrbracket
\]

is its mathematical meaning.

The initial algebra has:

### Empty

\[
\llbracket Empty\rrbracket=\varnothing
\]

### Pure

\[
\llbracket Pure(x)\rrbracket=\{x\}
\]

### Sum

\[
\llbracket A+B\rrbracket
=
Left(\llbracket A\rrbracket)
\cup
Right(\llbracket B\rrbracket)
\]

### Product

\[
\llbracket A\times B\rrbracket
=
\llbracket A\rrbracket\times\llbracket B\rrbracket
\]

---

# 19. Set, Multiset, Sequence

Three semantics must remain separate.

## Set

Membership.

```text
x ∈ S
```

## Multiset

Membership plus multiplicity.

## Sequence

Membership plus multiplicity plus order.

For example:

```text
A
B
A
```

is:

```text
set      = {A,B}
multiset = {A×2,B×1}
sequence = [A,B,A]
```

A search engine often operates on sequences.

A mathematical domain often uses sets.

A partition often uses sets.

A runtime scheduler may use queues.

These are not interchangeable.

---

# 20. Enumeration

Enumeration is an operational interpretation:

\[
E(e)=
[x_0,x_1,x_2,\ldots]
\]

The contract must state:

- soundness;
- completeness;
- determinism;
- productivity;
- fairness;
- duplicate policy.

A sequence is not the denotation.

---

# 21. Soundness

Enumeration is sound if:

\[
x\text{ is emitted}
\Rightarrow
x\in\llbracket e\rrbracket
\]

No invalid candidate may be generated.

---

# 22. Completeness

Enumeration is complete if every denotational member is eventually emitted, subject to the specified assumptions.

For infinite domains this is an eventual property.

It is not the same as termination.

---

# 23. Productivity

An infinite enumerator is productive if it keeps producing finite observable outputs.

A program can be non-terminating and productive.

For example:

```text
0
1
2
3
...
```

never terminates but remains productive.

---

# 24. Fairness

Fairness requires a precise definition.

The phrase:

> no branch is starved

is insufficient.

A fairness theorem must specify:

- what a branch is;
- what makes it eligible;
- what counts as starvation;
- the scheduling assumptions;
- the productivity assumptions.

Fairness is therefore an operational theorem.

---

# 25. Infinite Products

For:

\[
\mathbb N\times\mathbb N
\]

a naive left-biased enumeration can starve entire regions.

A diagonal strategy can enumerate:

```text
(0,0)

(0,1)
(1,0)

(0,2)
(1,1)
(2,0)

...
```

The anti-diagonal (Cantor pairing) strategy is sound and fair **only**
under the following precisely stated hypothesis, which the earlier
wording ("explicit assumptions") left unstated:

\[
\boxed{
\text{Diagonal-Fair}(E_1,E_2) \iff
\forall n.\ \big(|prefix_n(E_1)| = n+1\big) \wedge \big(|prefix_n(E_2)| = n+1\big)
}
\]

i.e. both component enumerators must be **infinite and index-complete at
every rank** — rank \(k\) of each enumerator must be available after a
bounded number of steps, uniformly. This hypothesis **fails** for a
mixed finite/infinite product such as \(A \times \Sigma^{*}\) where
\(A\) is a finite set exhausted after \(|A|\) elements: the standard
anti-diagonal schedule, applied unmodified, keeps revisiting indices into
\(A\) that no longer exist, which is either a runtime error or silent
starvation of the \(\Sigma^{*}\) component, depending on implementation.

The corrected contract is therefore a case split, not a single strategy:

```text
Sum/Product component capability    required enumeration strategy
─────────────────────────────────────────────────────────────────
finite  × finite                    any complete strategy (e.g. row-major)
finite  × infinite                  fix the finite index, diagonalize
                                     only over the infinite component
                                     (degenerates to sequential sweep)
infinite × infinite                 anti-diagonal, under Diagonal-Fair
```

`Analysis.Finiteness` (§42, Layer B) must classify each operand of a
`Product`/`Sum` **before** the planner selects an enumeration strategy;
selecting anti-diagonal unconditionally for a `Product` whose finiteness
has not been established is a planning bug, not a mathematical one — see
§182's planner-correctness obligation, which this is a direct instance
of. The implementation must prove this case split exhaustive and test
each branch against the reference semantics (§76), not merely assert the
general diagonal strategy and move on.

---

# 26. Sequences

Passwords are only one example of a more general construction.

For an alphabet \(A\):

\[
A^0=1
\]

\[
A^{n+1}=A\times A^n
\]

and:

\[
A^*=1+A\times A^*
\]

This is the algebra of finite sequences.

The important insight is:

> Password search is a language-enumeration problem.

That is more general than passwords.

---

# 27. Finite-Length Search

For an alphabet:

\[
\Sigma
\]

a fixed-length candidate language is:

\[
\Sigma^n
\]

Its cardinality is:

\[
|\Sigma^n|=|\Sigma|^n
\]

For lengths \(m\) through \(n\):

\[
\bigcup_{k=m}^{n}\Sigma^k
\]

with:

\[
\sum_{k=m}^{n}|\Sigma|^k
\]

The implementation should derive these values from the specification.

---

# 28. The Utility's First Mathematical Demonstration

The first real utility should demonstrate:

```text
finite alphabet
+
sequence construction
+
candidate ordering
+
external verifier
+
parallel partitioning
+
checkpointing
```

It should not initially support every file format.

One complete end-to-end domain is more valuable than many incomplete adapters.

---

# 29. Application-Level Problem

The utility's real problem is:

```text
Domain
+
Predicate/Verifier
+
Order
+
Execution policy
```

Conceptually:

\[
Problem(D,P,\prec)
\]

The domain is mathematical.

The verifier may be effectful.

The order is semantic.

The execution policy is operational.

Do not put all four into one datatype.

---

# 30. Predicate Versus Verifier

A pure predicate:

```haskell
a -> Bool
```

is not equivalent to a real-world verifier.

A verifier may encounter:

```text
Accepted
Rejected
Malformed input
Unsupported format
I/O error
Resource exhaustion
Timeout
```

Therefore:

```haskell
data Verification e
    = Rejected
    | Accepted
    | Failed e
```

is conceptually stronger.

A failure is not rejection.

---

# 31. Verification Soundness

A verifier is sound if:

\[
Accepted(x)\Rightarrow P(x)
\]

No invalid candidate may be accepted.

---

# 32. Verification Completeness

A verifier is complete if, under its assumptions:

\[
P(x)\Rightarrow Accepted(x)
\]

The search engine must not silently assume either property for arbitrary external adapters.

---

# 33. The Utility Should Be Verifier-Agnostic

The search engine should not know:

```text
PDF
ZIP
Office
database
configuration
```

It should know:

```text
Candidate
Verifier
Verification
```

The adapter owns the application-specific interpretation.

Thus:

```text
search calculus
        ↓
candidate
        ↓
verifier adapter
        ↓
Accepted / Rejected / Failed
```

---

# 34. Canonical Search

There are two important operations.

## Any solution

\[
findAny(D,P)
\]

returns any:

\[
x\in D
\]

such that:

\[
P(x)
\]

## Canonical solution

\[
findCanonical(D,P,\prec)
=
\min_\prec\{x\in D\mid P(x)\}
\]

These are not interchangeable.

---

# 35. Order Theory

A canonical solver requires more than “an order”.

Possible structures include:

```text
preorder
partial order
total order
well-order
```

A total order is not necessarily a well-order.

For example:

\[
\mathbb Z
\]

under ordinary `<` is totally ordered but not well-ordered.

The negative integers have no minimum.

The precise requirement is sharper than "the domain is well-ordered" and
must be stated against the solution set, not the domain, because a
domain can be ill-ordered overall while every predicate the engine is
ever asked to solve happens to have a well-ordered solution set under
\(\prec\):

\[
\boxed{
findCanonical(D,P,\prec) \text{ is well-defined} \iff
\big(Sol(D,P),\ \prec\big) \text{ has no infinite strictly-}\prec\text{-descending chain}
}
\]

equivalently, every non-empty subset of \(Sol(D,P)\) has a
\(\prec\)-minimum — i.e. \(\prec\) restricted to \(Sol(D,P)\) is a
well-order, **not** \(\prec\) restricted to \(D\). This is strictly
weaker and strictly more useful: \(D = \mathbb Z\) under `<` is not a
well-order, yet `findCanonical(ℤ, (> -5), <)` is perfectly well-defined
because `Sol` here is bounded below. The analysis engine (§42, Layer B)
must therefore attempt to establish well-foundedness of \(\prec\) on
\(Sol(D,P)\) specifically — using whatever bound information the
predicate and order jointly supply — and report `Unknown` rather than
`Yes`/`No` when it cannot. `findCanonical` is a partial operation whose
totality is exactly this proof obligation; §182's planner-correctness
contract for canonical search is this condition, stated operationally.

---

# 36. First Result Versus Minimum

The first enumerated solution is not automatically the canonical minimum.

Consider:

```text
4
3
2
1
```

The first satisfying result may be `4`.

The canonical minimum is `1`.

Therefore:

\[
first(E(e))
=
min_\prec(S)
\]

only under appropriate conditions, such as a complete enumeration that is monotone/nondecreasing with respect to the canonical order and assumptions sufficient to establish minimality.

This distinction is essential for parallel execution.

---

# 37. Parallel Canonical Search

Suppose workers find:

```text
worker A → 900
worker B → 400
worker C → 700
```

The first result is not necessarily canonical.

If `400` is found, the engine must still rule out:

```text
x < 400
```

in every unexplored region.

Therefore a canonical parallel solver needs more than partitions.

It needs **lower-bound information** or another proof of minimality.

---

# 38. Ordered Partitions

A future partition abstraction should therefore be capable of describing:

```text
region
+
coverage
+
disjointness
+
lower bound
```

Conceptually:

```haskell
Partition a =
    Region
    + LowerBound
```

The exact type should be developed only after the mathematical laws are established.

This is an important research direction.

---

# 39. Partitioning

A partition satisfies:

\[
S=\bigcup_i S_i
\]

and:

\[
i\neq j\Rightarrow S_i\cap S_j=\varnothing
\]

The first implementation should guarantee:

```text
coverage
disjointness
determinism
reconstruction
```

Balanced cardinality is not enough.

---

# 40. Cardinality Versus Cost

Equal cardinality does not imply equal runtime.

\[
|S_i|\approx|S_j|
\]

does not imply:

\[
Cost(S_i)\approx Cost(S_j)
\]

because verification cost may vary.

The system must therefore separate:

```text
mathematical cardinality
candidate-generation cost
verification cost
scheduling cost
wall-clock time
```

---

# 41. Cost Models

Cost is not intrinsic to a mathematical domain.

It depends on an execution model.

Conceptually:

\[
Cost(A,M)
\]

where:

- \(A\) is an algorithm;
- \(M\) is a machine/execution model.

Possible models include:

```text
abstract step model
CPU model
memory model
I/O model
parallel model
```

The calculus should not pretend that “runtime” is a property of the mathematical set.

---

# 42. Analysis Results

A universal:

```text
Known | Unknown
```

is too weak as a general analysis abstraction.

Different analyses have different uncertainty structures.

Cardinality might be:

```text
Finite n
Infinite
At least n
At most n
Unknown
```

Cost might be:

```text
Exact
Upper bound
Lower bound
Asymptotic
Unknown
```

Finiteness might be:

```text
Finite
Infinite
Unknown
```

Each analysis should have its own result type.

---

# 43. Lawful Interpretation

“Many interpretations” is meaningful only if each interpretation has a correctness contract.

An interpretation consists of:

```text
Interpreter
+
Semantic contract
+
Correctness law
```

Examples:

```text
Enumeration
    soundness
    completeness
    productivity
    fairness

Cardinality
    equals mathematical cardinality

Partition
    coverage
    disjointness

Cost
    equality or bound under a declared model

Planner
    preserves the requested search contract
```

This turns “many interpreters” from a slogan into an engineering discipline.

---

# 44. Planner

The planner is the missing bridge between mathematical specification and runtime.

Its job is to derive an execution plan.

Conceptually:

\[
Plan:
Specification
\rightarrow
ExecutionPlan
\]

A plan may contain:

```text
enumerator
partition strategy
worker count
ordering strategy
checkpoint strategy
verifier
cancellation rules
```

But the plan must not alter the mathematical meaning.

---

# 45. Akshara Plan

Conceptually:

```haskell
data AksharaPlan a = ...
```

The final representation is deliberately unspecified at this stage.

A plan is not a search expression.

It is an executable interpretation of one.

Therefore:

\[
\boxed{
AksharaExpr
\neq
AksharaPlan
}
\]

---

# 46. Compiler Interpretation

The utility can be viewed as a compiler.

```text
Search language
      ↓
type checking
      ↓
semantic validation
      ↓
analysis
      ↓
planning
      ↓
execution plan
      ↓
runtime
```

This is a major conceptual improvement over “write a brute-force engine”.

The project becomes:

> A small compiler and runtime for typed mathematical search specifications.

---

# 47. Why This Is the Right Level

A conventional implementation starts with:

```text
for candidate in candidates:
    verify(candidate)
```

This is operationally correct but mathematically shallow.

The proposed implementation starts with:

\[
D,\;P,\;\prec
\]

and derives:

```text
enumeration
partition
solver
runtime
```

The loop becomes an implementation detail.

That is the desired outcome.

---

# 48. The Utility's User Model

A real user should eventually be able to say something equivalent to:

```text
search
    alphabet = lowercase + uppercase + digits
    length = 1..N
    order = length_then_lexicographic
    verifier = <authorized file verifier>
    execution = parallel
    workers = 8
    checkpoint = enabled
```

The CLI or configuration language is only a front-end.

Internally this becomes a typed specification.

---

# 49. Human-Facing DSL

The human-facing syntax should not expose Haskell implementation details.

It should express mathematical structure.

Conceptually:

```text
alphabet = Lower + Upper + Digit

candidate = Sequence(alphabet, length = 1..12)

order = LengthLexicographic

verify = FileVerifier(...)
```

This is a possible future syntax.

The exact language should emerge from the kernel rather than being designed independently.

---

# 50. CLI Is Not the Core

The CLI should:

1. parse a specification;
2. type-check it;
3. construct the typed representation;
4. invoke analysis;
5. invoke the planner;
6. execute the plan;
7. report results.

It should not implement search algorithms.

---

# 51. Configuration Is Not Semantics

These are execution configuration:

```text
worker count
memory limit
checkpoint interval
logging level
output destination
```

These are not mathematical semantics.

The same mathematical search should remain valid if:

```text
1 worker
```

becomes:

```text
16 workers
```

provided the execution contract is preserved.

---

# 52. Parallelism as an Interpretation

The same specification:

```text
S
```

can be interpreted as:

```text
enumerate(S)
```

or:

```text
parallelEnumerate(S, partitions)
```

The denotation remains unchanged.

Only the operational interpretation changes.

---

# 53. Cancellation

Cancellation is safe for `findAny` after a valid result.

For `findCanonical`, cancellation requires proof that no better candidate remains.

Therefore:

```text
found result
→ cancellation
```

is valid only under the appropriate solver contract.

---

# 54. Resumability

A checkpoint is not generally:

```text
search + integer position
```

because the true execution state may be a frontier.

Conceptually:

\[
Checkpoint =
SpecificationIdentity
+
PlanIdentity
+
Frontier
\]

The frontier may represent:

```text
remaining ranges
pending partitions
enumerator state
ordering state
verifier state where relevant
```

---

# 55. Resumability Is a Capability

Not every search is resumable.

This is intentional.

A search is resumable only when:

```text
specification is reproducible
plan is reproducible
frontier is serializable
verifier state is reconstructible
external artifact is stable
```

Therefore the type/system should eventually expose resumability as a capability.

---

# 56. External Artifact Identity

For file verification, a checkpoint must identify the artifact being searched.

At minimum, the adapter should be able to associate the checkpoint with:

```text
path or logical identifier
format
content identity/hash
relevant metadata
```

The exact identity policy belongs to the adapter.

The principle is:

> Never resume a computation against an silently different external artifact.

---

# 57. Verifier Configuration Identity

If changing verifier configuration changes results, the checkpoint identity must include the relevant verifier configuration.

For example:

```text
format interpretation
verification mode
resource policy
```

must not silently change between runs.

---

# 58. Security Boundary

The mathematical calculus is security-neutral.

The recovery utility must nevertheless enforce safe operational behavior.

The implementation should:

- operate only on data the operator is authorized to access;
- avoid logging candidate secrets;
- avoid storing recovered secrets unnecessarily;
- avoid putting plaintext secrets into checkpoints;
- minimize plaintext lifetime;
- distinguish verification failure from rejection.

The calculus itself should not contain application-specific secret-handling policy.

---

# 59. The First Real Utility

The first production-shaped utility should be deliberately narrow.

It should provide:

```text
typed search specification
finite sequence domains
deterministic ordering
candidate generation
one real verifier adapter
parallel execution
checkpoint/resume for closed specifications
structured results
CLI
```

It should **not** initially provide:

```text
dozens of formats
distributed computing
GPU execution
adaptive heuristics
opaque plugin systems
unbounded symbolic optimization
```

The first utility should be mathematically complete enough to validate the architecture.

---

# 60. Recovery Utility as a Domain Adapter

The application architecture becomes:

```text
             SEARCH CALCULUS
                    │
                    ▼
             Search specification
                    │
                    ▼
                 Planner
                    │
                    ▼
             Execution engine
                    │
                    ▼
               Candidate
                    │
                    ▼
              File verifier
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
       Accepted  Rejected   Failed
```

The file verifier is replaceable.

The search engine is not tied to the file format.

---

# 61. Generalization

Once the utility works, the same engine should be able to search:

```text
integers
finite strings
finite sequences
records
configuration spaces
test cases
ASTs
symbolic terms
state spaces
authorized recovery candidates
```

The domain determines the mathematics.

The runtime does not care.

---

# 62. The Search Language as a Small Programming Language

The deeper interpretation is that the project is building a tiny programming language.

Its programs describe:

```text
domains
transformations
predicates
orders
```

Its compiler derives:

```text
enumerators
analyses
partitions
execution plans
```

Its runtime performs:

```text
candidate generation
verification
parallel scheduling
checkpointing
```

This is more ambitious than a utility but still grounded in a real utility.

---

# 63. Type System

The type system should prevent category errors such as:

```text
using a verifier as a domain
using a partition as a domain
using an execution strategy as a mathematical constructor
using a runtime value as a symbolic predicate
```

The goal is:

\[
\boxed{
\text{Invalid semantic compositions should be rejected by construction}
}
\]

---

# 64. Smart Constructors

Smart constructors are appropriate where they establish real invariants.

Examples:

```text
Workers > 0
LengthRange has valid bounds
PartitionCount > 0
Checkpoint is structurally valid
```

Do not create smart constructors merely to make the API look sophisticated.

---

# 65. Totality

The project should not claim that Haskell's type system makes the entire system total.

This is false.

For example:

```haskell
Map undefined ...
```

is type-correct.

The correct statement is:

> The project avoids deliberate partial APIs at semantic boundaries and represents recoverable failure explicitly.

This is an engineering invariant, not a theorem of Haskell.

---

# 66. Totality Versus Termination

These remain distinct:

```text
type totality
semantic totality
termination
productivity
fairness
completeness
```

A function can be total and non-terminating.

An enumerator can be productive and non-terminating.

A search can be complete without being able to prove that no solution exists.

The documentation must preserve these distinctions.

---

# 67. Recursive Search

The calculus eventually needs:

\[
\mu X.F(X)
\]

for recursive domains.

For example:

\[
List(A)=1+A\times List(A)
\]

This opens the door to:

```text
recursive grammars
AST generation
term generation
state spaces
```

But recursive search must wait until:

```text
least fixed-point semantics
productivity
fairness
termination
cost
partitioning
checkpointing
```

are defined.

---

# 68. The Utility as a Compiler Test

Every new language feature must pass two tests.

## Mathematical test

Can its meaning be stated precisely?

## Utility test

Can it enable a useful capability in the actual program?

If a feature passes only the second test, it belongs in the runtime.

If it passes only the first test but has no useful interpretation, it may remain a research construct.

If it passes both, it belongs in the core.

---

# 69. Three Categories of Features

Every proposed feature should be classified as one of:

```text
CALCULUS
    mathematical syntax

ANALYSIS
    derived mathematical/operational information

RUNTIME
    execution machinery
```

This classification prevents abstraction leakage.

---

# 70. Example: Worker Count

`8 workers` is:

```text
RUNTIME
```

It is not part of the search domain.

---

# 71. Example: Lexicographic Order

Lexicographic order is:

```text
SEMANTIC
```

because it affects what “canonical” means.

---

# 72. Example: Checkpoint Interval

`checkpoint every 60 seconds` is:

```text
RUNTIME POLICY
```

It does not change the mathematical search.

---

# 73. Example: Candidate Length

`length 8` is:

```text
CALCULUS
```

because it changes the domain.

---

# 74. Example: Lower Bound

A lower bound used to prove canonicality is:

```text
ANALYSIS / PLAN
```

It describes operationally useful information derived from the domain and order.

---

# 75. Example: File Format

A file format is:

```text
VERIFIER ADAPTER
```

It should not infect the calculus.

---

# 76. Reference Semantics

Testing must include a trusted finite reference semantics.

For finite expressions:

```text
AksharaExpr
    ↓
ReferenceSet
```

can be used as an oracle.

The optimized implementation must be compared against it.

This is stronger than testing the optimized implementation against itself.

---

# 77. Algebraic Testing

The following should be explicit metamorphic tests:

\[
map\ id\ A\equiv_D A
\]

\[
map\ f(map\ g(A))
\equiv_D
map(f\circ g,A)
\]

and appropriate isomorphism-aware laws for:

\[
A+0
\]

\[
A+B
\]

\[
(A+B)+C
\]

\[
A\times(B\times C)
\]

These are not merely unit tests.

They test the algebra.

---

# 78. Enumeration Testing

For finite expressions:

\[
set(enumerate(e))
=
\llbracket e\rrbracket
\]

subject to duplicate policy.

But also test:

```text
order
multiplicity
determinism
```

Do not convert every result to a set and thereby erase operational bugs.

---

# 79. Infinite Testing

Infinite enumerators cannot be compared by whole-stream equality.

Instead test eventual properties.

For a selected finite witness \(x\):

\[
x\in\llbracket e\rrbracket
\Rightarrow
\exists n.\ x\in prefix_n(E(e))
\]

under the declared completeness assumptions.

---

# 80. Parallel Testing

For `findAny`:

```text
result is accepted
```

For `findCanonical`:

```text
parallel result
=
reference canonical result
```

The number of workers must not change the semantic answer.

---

# 81. Checkpoint Testing

A robust test is:

```text
run
↓
interrupt
↓
persist checkpoint
↓
restart
↓
resume
↓
compare with uninterrupted run
```

For deterministic jobs:

\[
Result(resume)=Result(full)
\]

The test should include interruptions at arbitrary valid frontier boundaries.

---

# 82. Property: Partition Equivalence

For a deterministic partition:

\[
S=\bigcup_iS_i
\]

and:

\[
S_i\cap S_j=\varnothing
\]

for:

\[
i\neq j
\]

Then searching all partitions should be extensionally equivalent to searching the whole domain.

---

# 83. Property: Worker Independence

This property is **solver-contract-indexed**, not a blanket claim — a
blanket "worker count never changes the result" directly contradicts
§37, which establishes that a race-to-first-result scheme over partitions
gives the *wrong* canonical answer regardless of worker count. The
correct statement is three separate properties:

```text
findAny:
    changing 1 worker → N workers
    must not change Accepted(result) — any valid x remains valid.
    WHICH x is returned may differ; that is permitted by findAny's contract.

findExhaustive:
    changing 1 worker → N workers
    must not change the Found/Exhausted/Inconclusive outcome,
    given partition coverage + disjointness (§39, §82).

findCanonical:
    changing 1 worker → N workers
    preserves the result ONLY IF the plan carries a lower-bound
    capability per region (§37, §38). Without it, worker-count
    independence for findCanonical is NOT guaranteed and must not
    be asserted as a property — it is instead a precondition to be
    established by the planner and checked by §160's proof-obligation
    discipline before the property is claimed at all.
```

In every case what may vary freely is:

```text
runtime
memory
ordering of internal events
```

never the declared result contract for the solver actually in use — and
for `findCanonical` specifically, the declared result contract itself is
conditional on lower-bound capability, so the property test for §83 must
be written against that capability flag, not unconditionally.

---

# 84. Benchmarking

Benchmarks must isolate:

```text
domain construction
candidate enumeration
verification
partitioning
scheduling
checkpointing
I/O
```

A single “total runtime” number is insufficient.

In many real workloads:

\[
Cost(verifier)\gg Cost(generator)
\]

Therefore optimizing the generator may produce negligible benefit.

---

# 85. Runtime Metrics

The utility should expose structured metrics such as:

```text
candidates generated
candidates verified
accepted
rejected
failed verification
generation rate
verification rate
elapsed time
active workers
checkpoint count
resume count
```

These are runtime observations.

They are not part of the mathematical semantics.

---

# 86. Failure Model

The runtime must distinguish:

```text
NoSolution
Accepted candidate
VerificationFailure
ConfigurationError
SpecificationError
CheckpointMismatch
RuntimeFailure
Cancelled
```

A failure must not silently become:

```text
NoSolution
```

This distinction is especially important for exhaustive search.

---

# 87. Exhaustiveness

An exhaustive search may conclude:

```text
No solution
```

only when:

1. the domain is known to be exhausted;
2. enumeration is complete;
3. all relevant candidates were verified;
4. no unrecoverable verifier failure invalidates the conclusion.

Therefore:

\[
NoSolution
\]

is stronger than:

```text
Nothing found yet
```

---

# 88. Three Search Outcomes

The utility should conceptually distinguish:

```text
Found
NotFound
Inconclusive
```

where:

```text
Found
    a valid candidate was established.

NotFound
    the search domain was exhausted under a sound/complete verifier.

Inconclusive
    execution could not establish either result.
```

This is more correct than simply returning `Maybe a`.

---

# 89. Why `Maybe a` Is Insufficient for the Utility

`Maybe a` conflates:

```text
no solution
```

with:

```text
search failed
```

and:

```text
search was interrupted
```

A production utility needs a richer result.

---

# 90. Suggested Result Algebra

The naive version is unsound at the type level: `Found a` cannot be
produced by `findAny`, `findCanonical`, and `findExhaustive` alike
without erasing exactly the distinction §36 and §182 insist on —
"first result" and "canonical minimum" become the same constructor, so
nothing stops a caller from treating an uninvestigated `findAny` result
as canonical. This is precisely the "illegal states unrepresentable"
failure the engineering standard (1.2, 3.1) forbids, and the fix is the
standard's own toolkit entry 3.4/3.5: a phantom `SolverKind` index, so
the compiler — not a convention, not a comment — distinguishes the two.

```haskell
data SolverKind = AnySolve | CanonicalSolve | ExhaustiveSolve

-- | 'Found' for 'CanonicalSolve' additionally carries the minimality
-- witness required by §35/§182: a proof object asserting that every
-- x' < result in Sol(D,P) has been ruled out, not merely "not yet seen."
-- No such witness exists for 'AnySolve' — the type has no slot for one,
-- so it is a compile error, not a convention, to treat an AnySolve
-- result as canonical downstream.
data AksharaResult (k :: SolverKind) e a where
    FoundAny        :: a                    -> AksharaResult 'AnySolve        e a
    FoundCanonical  :: a -> MinimalityProof  -> AksharaResult 'CanonicalSolve e a
    Exhausted       :: AksharaResult k e a
    Inconclusive    :: AksharaResult k e a
    Failed          :: e -> AksharaResult k e a

-- | Opaque: constructed only by a solver that has actually discharged
-- the proof obligation of §35/§182 (e.g. lower-bound exhaustion over
-- every unexplored partition, §37). Never exported with a public
-- constructor — see 3.3's smart-constructor discipline.
newtype MinimalityProof = UnsafeMinimalityProof LowerBoundCertificate
```

The semantic distinction is now four-way, matching §88/§182, and
solver-kind-indexed:

```text
Found (with solver-appropriate evidence)
vs
Exhausted      -- domain proven complete, no solution exists
vs
Inconclusive   -- neither established (cancelled, resource-limited, etc.)
vs
Failed         -- a named, structured failure (§177), never silently NoSolution
```

`findAny :: ... -> m (AksharaResult 'AnySolve e a)` and
`findCanonical :: ... -> m (AksharaResult 'CanonicalSolve e a)` now have
return types that *cannot* be confused at a call site — the phantom
index is Least Power (0.10) applied to the solver boundary itself.

---

# 91. Search Engine Boundary

The engine should receive:

```text
AksharaPlan
Verifier
ExecutionPolicy
```

and produce:

```text
AksharaResult
```

The engine should not construct the domain itself.

---

# 92. Execution Policy

Execution policy may include:

```text
worker count
scheduling
resource limits
checkpoint policy
cancellation policy
metrics
```

This is runtime configuration.

---

# 93. Determinism

The mathematical specification should be deterministic unless nondeterminism is explicitly part of the semantics.

Runtime scheduling may be nondeterministic.

That does not necessarily make the search result nondeterministic.

For `findAny`, different workers may return different valid answers.

For `findCanonical`, the answer must remain canonical.

---

# 94. Reproducibility

Reproducibility means:

```text
same specification
+
same semantics
+
same external artifact
+
same relevant configuration
```

produces equivalent results.

It does not necessarily mean identical thread scheduling.

---

# 95. Optimization Boundary

Optimization must preserve the semantic contract.

Examples:

```text
fusing maps
reordering independent operations
partitioning
parallelizing
caching
short-circuiting
```

are valid only when their correctness conditions are established.

Optimization is therefore another interpretation-preserving transformation.

---

# 96. Compiler Optimizations

Once the kernel is symbolic, the planner can potentially perform:

```text
constant folding
dead branch elimination
predicate simplification
map fusion
domain restriction
bound propagation
partition derivation
```

These are not available reliably when arbitrary Haskell functions are opaque.

This is another reason for the Kernel/Host distinction.

---

# 97. The Kernel Should Be Small

The kernel should not become a giant theorem prover.

The target is:

```text
small
typed
composable
lawful
serializable
interpretable
```

A larger language is not automatically a better abstraction.

---

# 98. The Host Extension Should Be Honest

Host expressions may be:

```text
more expressive
less analyzable
less serializable
less optimizable
```

This is acceptable.

The system should report capabilities honestly.

For example:

```text
Serializable: yes/no
Analyzable: exact/partial/unknown
Resumable: yes/no
Parallelizable: yes/no
```

---

# 99. Capability Model

A useful future direction is to model capabilities explicitly.

Possible capabilities:

```text
Finite
Enumerable
Serializable
Partitionable
Orderable
Resumable
Analyzable
Canonicalizable
```

Not every expression possesses every capability.

This is a stronger abstraction than a single universal `AksharaExpr`.

---

# 100. Capability Is Not a Boolean Property in Every Case

Some capabilities have degrees.

For example:

```text
Analysis:
    exact
    bounded
    unknown

Enumeration:
    finite
    infinite productive
    unknown

Canonical search:
    exact
    conditional
    unavailable
```

Capability types may therefore need richer evidence than simple flags.

---

# 101. Dependent-Type Direction

The project should investigate whether some invariants should move into the type level.

Potential examples:

```text
NonEmpty
PositiveNatural
FiniteLength
OrderedDomain
```

But type-level machinery should be introduced only where it reduces semantic ambiguity.

The project is not a demonstration of advanced Haskell extensions.

It is a demonstration of mathematical structure.

---

# 102. No Accidental Type-Level Complexity

Do not use:

```text
DataKinds
type families
singletons
GADTs
```

merely because they are sophisticated. The test (engineering standard
3.5) is precise, not a vibe: reach for a GADT exactly when a plain ADT
would force constructors to share one result type despite producing
logically different types, and the alternative is an unsafe cast or a
partial extraction function (`asInt`, `asBool`-style) — i.e. exactly
when the GADT *removes* a partiality that Part 1 of the engineering
standard would otherwise prohibit.

This document is not GADT-free — it should not be. `AksharaExpr a`
(§12) is type-indexed by its denotation's carrier type by construction;
a plain ADT cannot express `Product :: AksharaExpr a -> AksharaExpr b ->
AksharaExpr (a, b)` without an existential plus an unsafe downcast at
every consumer. `Transform a b` and `Predicate a` (§13–14) are GADTs for
the identical reason. `AksharaResult (k :: SolverKind) e a` (§90) uses
`DataKinds` because `FoundCanonical`'s minimality witness is a real
invariant with no sound representation as a boolean flag. Each of these
is a discharged instance of the 3.5 test, not an exception to §102 — the
rule and the sketches are consistent once "merely because sophisticated"
is read as excluding "because it closes a stated partiality or
confusability hole," which is the actual bar every type-level
construct in this document must clear, and is cited by section number
at each use site above rather than left implicit.

---

# 103. Mathematical Transparency

The project should not optimize for minimum LOC.

A 50-line abstraction that requires a 500-line explanation is not necessarily superior to a 100-line abstraction that directly expresses the mathematics.

The actual target is:

\[
\boxed{
\frac{\text{mathematical transparency}}
{\text{accidental complexity}}
}
\]

---

# 104. Semantic Density

“Semantic density” is useful only as a secondary heuristic.

High semantic density can become dangerous if:

```text
too many concepts are compressed into one type
```

The correct goal is:

> Maximum mathematical transparency with minimum accidental complexity.

---

# 105. Module Architecture

A candidate project structure:

```text
src/
  Akshara/
    Syntax.hs
    Domain.hs
    Transform.hs
    Predicate.hs
    Order.hs
    Semantics.hs
    Enumeration.hs
    Analysis/
      Cardinality.hs
      Finiteness.hs
      Bounds.hs
      Cost.hs
    Partition.hs
    Plan.hs
    Solver.hs
    Result.hs

  Runtime/
    Engine.hs
    Scheduler.hs
    Worker.hs
    Checkpoint.hs
    Metrics.hs

  Verify/
    Class.hs
    Errors.hs
    Formats/

  CLI/
    Parse.hs
    Command.hs
    Render.hs
```

The kernel calculus lives under the `Akshara.*` namespace; `Runtime.*`,
`Verify.*`, and `CLI.*` remain separately named per §2.10 of the
engineering standard, since they are not the kernel — only the
mathematical core carries the project's name, matching §196's point
that `Akshara`/`AksharaExpr` is a candidate object, not a fixed one.

The final module structure may change.

The dependency direction must not.

---

# 106. Dependency Direction

Preferred:

```text
Search
  ↓
Analysis / Planning
  ↓
Runtime
  ↓
Adapters / CLI
```

Never:

```text
Search
  ↓
PDF parser
```

or:

```text
Search
  ↓
threading library
```

The mathematical core must remain independent.

---

# 107. Stage Plan

## Stage 0 — Research Kernel

Define:

```text
syntax
denotation
laws
finite reference semantics
```

No runtime.

---

## Stage 1 — Minimal Algebra

Implement:

```text
Empty
Pure
Sum
Product
```

Prove/test their finite semantics.

---

## Stage 2 — Symbolic Transformations

Introduce a minimal symbolic transformation language.

Do not begin with arbitrary `Map`.

---

## Stage 3 — Symbolic Predicates

Introduce:

```text
True
False
And
Or
Not
```

plus only the domain predicates actually required.

---

## Stage 4 — Enumeration

Implement deterministic finite enumeration.

---

## Stage 5 — Infinite Enumeration

Add:

```text
fair sums
fair products
finite sequences
```

with explicit theorem assumptions.

---

## Stage 6 — Orders and Solvers

Implement:

```text
findAny
findCanonical
```

with separate contracts.

---

## Stage 7 — Analysis

Implement:

```text
cardinality
finiteness
bounds
depth
```

with analysis-specific result types.

---

## Stage 8 — Planner

Derive:

```text
ExecutionPlan
```

from the specification and analysis.

---

## Stage 9 — Partitioning

Implement deterministic partitioning.

---

## Stage 10 — Parallel Runtime

Implement:

```text
workers
scheduling
cancellation
failure propagation
```

---

## Stage 11 — Checkpointing

Support only closed, reproducible specifications.

---

## Stage 12 — Verifier Boundary

Add:

```text
Verifier
Verification
```

and one real adapter.

---

## Stage 13 — First Utility

Deliver the first usable command-line utility.

It must perform a complete authorized search workflow.

---

## Stage 14 — Additional Adapters

Only after the first end-to-end path is stable.

---

## Stage 15 — Optimization

Only after profiling.

---

# 108. First Utility Milestone

The first useful release should answer:

> Can the calculus express a realistic finite candidate space, can the planner derive an executable search, and can the runtime search it correctly in sequential and parallel modes?

Success criteria:

```text
same specification
→ sequential result
→ parallel result
→ checkpoint/resume result
```

all agree semantically.

---

# 109. Second Utility Milestone

The second milestone should demonstrate:

```text
multiple candidate domains
```

using the same runtime.

For example:

```text
strings
+
integer tuples
+
records
```

If this requires changes to the runtime, investigate why.

---

# 110. Third Utility Milestone

Introduce a second verifier adapter.

The search engine should remain unchanged.

If:

```text
Verifier A
```

and:

```text
Verifier B
```

both plug into the same engine, the abstraction has demonstrated real value.

---

# 111. Fourth Utility Milestone

Introduce a human-readable specification format.

The same specification should be:

```text
parsed
typed
analyzed
planned
executed
```

without bypassing the calculus.

---

# 112. Fifth Utility Milestone

Introduce optimizer passes.

For example:

```text
specification
    ↓
normalize
    ↓
simplify
    ↓
derive bounds
    ↓
partition
    ↓
execute
```

The optimized and unoptimized forms must be semantically equivalent.

---

# 113. Utility CLI

A conceptual interface:

```text
search <specification>
```

Possible operations:

```text
search validate
search analyze
search plan
search run
search resume
search inspect
```

These should map directly onto the internal architecture.

---

# 114. `validate`

Checks:

```text
typing
semantic constraints
external artifact identity
verifier configuration
```

It should not execute the search.

---

# 115. `analyze`

Reports:

```text
cardinality
finiteness
bounds
estimated cost
partitionability
capabilities
```

Unknown values must be reported as unknown.

The program must never fabricate precision.

---

# 116. `plan`

Shows the derived execution plan:

```text
enumerator
order
partitioning
workers
checkpoint capability
verifier
```

This is valuable both for users and for debugging the abstraction.

---

# 117. `run`

Executes the plan.

The runtime reports structured progress.

---

# 118. `resume`

Loads a checkpoint only after validating semantic identity.

A mismatch is an error.

Never silently resume a different computation.

---

# 119. `inspect`

Shows the mathematical specification in normalized form.

This creates an important feedback loop:

```text
human specification
→ kernel representation
→ normalized mathematical form
```

The user can inspect what the compiler thinks the problem means.

---

# 120. Normal Form

A future normalization pass may establish canonical structural forms.

Potential goals:

```text
flatten nested sums
flatten nested products
simplify identity transforms
remove empty branches
normalize ranges
combine equivalent constraints
```

Normalization must be justified by semantic laws.

---

# 121. Equality Hierarchy

The system must distinguish:

```text
Haskell equality
structural equality
type isomorphism
denotational equality
sequence equality
multiset equality
plan equivalence
execution-result equivalence
```

No one equality relation should be used for all purposes.

**Ordering dependency, stated explicitly because earlier drafts left it
implicit:** every later section that invokes an unqualified phrase like
"reconstructs the same semantic object" or "produces an equivalent
result" — specifically §120 (normal form), §149 (serialization
round-trip), §150 (serialization), and §153 (deterministic planning) —
is **unfalsifiable** until it names *which* relation from this list it
means. "Serialization reconstructs the same semantic object" (§149) is
vacuous as stated: structural equality is far stronger than denotational
equivalence (§123 — same denotation, different enumeration order is
common and acceptable), and a round-trip law stated against the wrong
relation in this list will either reject valid optimizations or silently
accept unsound ones. Each of §120/§149/§150/§153 is hereby read as
binding to **denotational equality** (§122) unless that section
explicitly names a different relation from this list — this document
does not leave that binding to the reader's inference from here forward.

---

# 122. Denotational Equivalence

\[
A\equiv_D B
\]

means:

\[
\llbracket A\rrbracket=\llbracket B\rrbracket
\]

under the required type isomorphism.

---

# 123. Enumeration Equivalence

Two expressions may have:

```text
same denotation
different enumeration
```

Therefore:

\[
A\equiv_D B
\]

does not imply:

\[
E(A)=E(B)
\]

---

# 124. Plan Equivalence

Two plans may have different:

```text
worker counts
partition structures
scheduling
```

yet produce the same canonical result.

Therefore:

```text
plan equality
```

is a separate concept.

---

# 125. Execution Equivalence

Execution may vary in:

```text
timing
thread scheduling
internal ordering
```

while preserving the declared semantic result.

This is the correct target for parallel optimization.

---

# 126. No Universal Equality

The project should never attempt to define:

```haskell
same :: AksharaExpr a -> AksharaExpr a -> Bool
```

as a universal semantic equality checker.

For arbitrary host functions this is impossible in general.

Even in the closed kernel, equivalence may be computationally difficult.

The correct approach is:

```text
normalization where possible
proof/laws
finite model comparison
property testing
```

---

# 127. Analysis Is Conservative

The analysis engine should prefer:

```text
Unknown
```

over a false theorem.

For example:

```text
Map opaqueFunction domain
```

may have unknown cardinality.

This is a feature, not a weakness.

---

# 128. Static Knowledge Forms a Lattice; Monotonicity and Soundness Are Separate Obligations

The earlier formulation — "adding information should refine, not
contradict" — is false as a free-standing principle and must not be
implemented as stated. A sequence

```text
Unknown → AtLeast 100 → Exactly 256
```

is monotone **only in the lattice-ordering sense below**; it is not
automatically *correct*. If the analysis producing `AtLeast 100` was
itself unsound — e.g. it treated `Map opaqueFunction domain` (§127) as
cardinality-preserving when `opaqueFunction` is not injective — then the
true cardinality may be less than 100, and a later, more careful pass
discovering `Exactly 60` is not a "contradiction of previously valid
information" to be rejected; it is a **correction of previously invalid
information** that must be accepted. Treating §128's original wording
literally would make the system prefer a wrong but earlier answer over a
right but later one, which inverts the entire purpose of conservative
analysis (§127).

The corrected formulation separates two independent properties that the
single word "monotone" conflated:

**1. Lattice structure (ordering of evidence strength).** Every analysis
result type (§42) is a bounded join-semilattice with `Unknown = ⊥`:

```text
Cardinality lattice (sketch):
    Unknown ⊑ AtLeast n ⊑ Exactly n      (for consistent n)
    Unknown ⊑ AtMost n  ⊑ Exactly n
```

Combining two independently-derived facts about the same expression uses
`⊔` (least upper bound), and `⊔` must be defined to produce `⊥`-below
only when the two facts are jointly consistent — it is a partial
operation, total only on the consistent sublattice, and the analysis
engine must detect and report `⊔`-failure (two incompatible exact facts)
as an internal analyzer defect, never silently pick one.

**2. Soundness (correctness of each individual judgment), non-negotiable
and un-weakened by lattice position.** Every analysis judgment `φ` the
system ever states — regardless of where it sits in the lattice — must
satisfy

\[
\boxed{
\text{analysis states } \varphi \Rightarrow \varphi \text{ holds of } \llbracket e \rrbracket
}
\]

A judgment that fails this is a **bug in the analyzer**, to be fixed by
replacing it with the weaker-but-sound `⊥`/`Unknown`, never papered over
by redefining "refinement" to tolerate it. Monotonicity describes how
*sound* facts compose as more of them accumulate; it never licenses
treating an unsound fact as provisionally acceptable because it arrived
first. §127's conservatism and this lattice are the same discipline
viewed from two angles: prefer `⊥` over an unsound non-`⊥` fact, always;
once a fact is stated, it must already be sound, not merely "probably
sound until revised."

---

# 129. Cost and Cardinality

For candidate generation:

\[
Work \approx
|D|\times Cost(candidate)
\]

but even this is simplistic.

Real work may be:

\[
Work =
Generation
+
Verification
+
Scheduling
+
I/O
\]

The system should preserve the distinction.

---

# 130. Parallel Cost

Parallel wall-clock behavior depends on:

```text
worker count
partition balance
verification variance
scheduler overhead
I/O contention
machine topology
```

Therefore:

\[
Cost_{parallel}(S,M,W)
\]

is an execution-model quantity.

It is not part of the denotation.

---

# 131. Distributed Execution

Distributed execution is explicitly out of the first release.

It should become possible later without changing the calculus.

That is an architectural test.

If distributed execution requires changes to `AksharaExpr`, investigate whether execution concerns leaked into the calculus.

---

# 132. GPU Execution

Likewise:

```text
GPU
SIMD
vectorization
```

are runtime interpretations.

They should not alter mathematical syntax.

---

# 133. Adaptive Scheduling

Adaptive scheduling may use:

```text
observed verifier cost
partition progress
failure rates
```

This belongs in the runtime.

It must preserve the search contract.

---

# 134. Security and Logging

The runtime should log:

```text
job identifier
specification identity
progress
rates
errors
checkpoint events
```

It should not log:

```text
candidate secrets
accepted passwords
plaintext credentials
```

unless explicitly and safely requested by an authorized operator.

---

# 135. File Recovery Scope

The file-recovery utility should support only authorized recovery of data controlled by the operator.

The research document is about:

```text
search mathematics
```

not unauthorized credential acquisition.

---

# 136. Adapter Design

Each verifier adapter should expose conceptually:

```text
artifact identity
supported candidate type
verification operation
failure taxonomy
resource policy
```

It should not expose its internal parsing machinery to the search calculus.

---

# 137. Adapter Correctness

Every adapter requires:

```text
soundness tests
negative tests
malformed-input tests
failure tests
determinism tests
resource-limit tests
```

The search engine cannot compensate for an unsound verifier.

---

# 138. First Adapter Selection

The first adapter should be chosen for:

```text
clear verification semantics
stable library support
reasonable testability
predictable candidate representation
```

The choice should be based on engineering value, not on the number of formats supported.

---

# 139. Test Corpus

The utility should maintain a controlled corpus containing:

```text
known-valid artifacts
known-invalid candidates
known-valid candidates
malformed artifacts
unsupported artifacts
resource-stress cases
```

This corpus belongs to integration testing.

---

# 140. Golden Tests

Useful golden outputs include:

```text
normalized specification
analysis report
execution plan
partition description
checkpoint metadata
final result
```

Golden tests make semantic regressions visible.

---

# 141. Reference Interpreter

The reference interpreter should be intentionally simple.

It may be slow.

That is desirable.

Its job is correctness, not performance.

The optimized runtime should be tested against it.

---

# 142. Trusted Base

The smallest trusted base should be:

```text
kernel semantics
reference interpreter
property suite
```

The optimized runtime should not be treated as its own proof.

---

# 143. Proof Versus Test

The project is not a theorem prover.

Use:

```text
mathematical reasoning
+
types
+
property tests
+
reference semantics
+
integration tests
```

together.

No single technique is sufficient.

---

# 144. Formalization Boundary

If the algebra becomes mathematically interesting enough, selected laws may later be formalized in:

```text
Agda
Coq
Lean
```

This is optional.

The Haskell implementation remains the primary executable artifact.

---

# 145. Why Haskell

Haskell is appropriate because it allows:

```text
algebraic data types
GADTs
type-directed interpretation
pure semantics
lazy infinite structures
equational reasoning
property testing
```

The language is not the research result.

The mathematics is.

---

# 146. Why Not Rust for This Experiment

Rust may be a stronger choice for:

```text
production systems programming
explicit resource management
predictable operational behavior
```

That is not the point.

Haskell is being used because the experiment asks:

> How directly can a mathematical search calculus become executable code?

That is precisely the kind of question for which Haskell is valuable.

---

# 147. Production Boundary

If the resulting utility later requires:

```text
extreme throughput
strict resource control
platform-specific integration
```

a Rust runtime could eventually be considered.

But the calculus should remain language-independent in principle.

A future architecture could be:

```text
mathematical IR
      ↓
Haskell reference runtime
      ↓
optimized native runtime
```

This is a later possibility, not a first-stage requirement.

---

# 148. Intermediate Representation

The kernel itself can become an intermediate representation.

Conceptually:

```text
User DSL
   ↓
Typed Search IR
   ↓
Normalized Search IR
   ↓
Execution Plan
   ↓
Runtime
```

This makes the project resemble a compiler architecture.

---

# 149. Why an IR Is Valuable

An intermediate representation allows:

```text
inspection
normalization
analysis
optimization
serialization
checkpoint identity
multiple backends
```

The mathematical expression becomes a durable artifact.

---

# 150. Serialization

Closed kernel specifications should be serializable.

A serialized specification should reconstruct the same semantic object.

Serialization should include:

```text
language version
schema version
domain specification
predicate specification
order
relevant semantic parameters
```

Opaque host functions should not be serialized as though they were portable.

---

# 151. Versioning

A persisted specification must identify:

```text
calculus version
schema version
adapter version
relevant semantic version
```

A runtime may reject incompatible specifications.

Semantic compatibility matters more than file-format compatibility.

---

# 152. Checkpoint Versioning

A checkpoint must identify:

```text
specification version
plan version
runtime compatibility
adapter identity
frontier encoding version
```

A newer runtime must not blindly consume an old checkpoint.

---

# 153. Deterministic Planning

Given:

```text
same closed specification
same planner version
same relevant configuration
```

the planner should derive an equivalent plan.

This is valuable for:

```text
debugging
reproducibility
checkpointing
benchmarking
distributed execution
```

---

# 154. Search Job Identity

A job identity can be derived conceptually from:

```text
specification identity
+
external artifact identity
+
verifier identity
+
semantic configuration
```

The exact hashing mechanism is an implementation detail.

The semantic inputs are not.

---

# 155. Observability

A running job should expose:

```text
job identity
domain size if known
processed count
remaining estimate if known
rate
workers
partition progress
checkpoint state
```

Unknown values should remain visibly unknown.

---

# 156. No Fake Progress

For infinite or poorly analyzable searches, do not invent:

```text
37% complete
```

unless the system has a defensible denominator.

Instead report:

```text
candidates processed
rate
elapsed
known bounds
```

This is a small but important example of mathematical honesty.

---

# 157. Utility User Experience

The utility should make the mathematics visible.

A user should be able to inspect:

```text
Domain:
    Σ^1 + Σ^2 + ... + Σ^12

Order:
    length then lexicographic

Cardinality:
    3,123,456,789

Partition:
    8 deterministic regions

Verifier:
    format X

Canonical:
    yes/no

Resumable:
    yes/no
```

The program becomes a practical mathematical instrument.

---

# 158. Explainability

When the planner makes a decision, it should eventually be possible to explain:

```text
why this partition
why this order
why canonical search is unavailable
why checkpointing is unavailable
why cardinality is unknown
```

This is particularly important when opaque host functions are present.

---

# 159. Capability Report

A useful analysis output:

```text
Finite:           yes
Enumerable:       yes
Fair:             yes
Cardinality:      exact
Canonical order:  yes
Canonical solve:  yes
Partitionable:    yes
Serializable:     yes
Resumable:        yes
Cost estimate:    bounded
```

This should be derived, not manually configured.

---

# 160. The Utility as a Proof Obligation

Every production feature should answer:

```text
What semantic contract does this feature preserve?
```

For example:

```text
parallelism
    preserves canonical result

checkpoint
    preserves remaining search frontier

optimization
    preserves denotation

partition
    preserves coverage/disjointness

verifier adapter
    preserves soundness
```

This makes the implementation disciplined.

---

# 161. Research Loop

The project should operate in this loop:

```text
mathematical hypothesis
        ↓
typed representation
        ↓
reference semantics
        ↓
property tests
        ↓
runtime interpretation
        ↓
real workload
        ↓
observed weakness
        ↓
refined mathematics
```

The real utility feeds evidence back into the theory.

---

# 162. What Would Count as Failure?

The experiment should be considered unsuccessful if:

```text
the calculus becomes huge
the runtime is mostly special cases
the types obscure rather than clarify
parallelism requires semantic hacks
checkpointing requires ad hoc state
verifiers leak into the core
the CLI bypasses the calculus
```

A working utility alone is not sufficient.

---

# 163. What Would Count as Success?

Strong success would look like:

```text
small kernel
+
precise laws
+
reference semantics
+
multiple interpreters
+
real executable utility
```

with the utility requiring surprisingly little application-specific search code.

That is the actual target.

---

# 164. The Strongest Architectural Test

Ask:

> If the password-recovery adapter is deleted, does the search engine still make complete sense?

It should.

Then ask:

> If the search engine is replaced by a different verifier, does the calculus remain unchanged?

It should.

Then ask:

> If the sequential runtime is replaced by a parallel runtime, does the mathematical specification remain unchanged?

It should.

If all three answers are yes, the abstraction boundary is probably sound.

---

# 165. Second Strongest Test

Ask:

> Can a mathematical expression be inspected without executing it?

It should.

Ask:

> Can its meaning be tested without the production runtime?

It should.

Ask:

> Can its execution strategy change without changing its denotation?

It should.

---

# 166. Third Strongest Test

Ask:

> Can the utility generate an execution plan from the mathematical specification without knowing the application domain?

Ideally yes.

If not, determine whether the missing knowledge belongs to:

```text
calculus
analysis
planner
verifier
```

and put it in the correct layer.

---

# 167. Minimal Mathematical Core

The ideal core should approach:

```text
Domain algebra
+
Transform algebra
+
Predicate algebra
+
Order
+
Semantics
```

Everything else should be derived if possible.

---

# 168. Minimal Runtime Core

The ideal runtime should approach:

```text
Plan
+
Scheduler
+
Verifier
+
Result
```

Everything else should be support infrastructure.

---

# 169. LOC Targets

LOC is a constraint, not the primary objective.

A realistic target is:

| Component | Target |
|---|---:|
| Kernel calculus | 300–700 |
| Symbolic predicates/transforms | 300–800 |
| Reference semantics | 200–400 |
| Enumeration | 300–600 |
| Analysis | 300–700 |
| Planner | 300–600 |
| Runtime | 500–1,000 |
| Checkpointing | 250–500 |
| First verifier adapter | 300–700 |
| CLI | 200–400 |
| Tests | 1,000–2,000 |
| **First serious system** | **~4,000–8,000** |

The mathematical kernel itself should remain substantially smaller.

---

# 170. Why the Estimate Increased

Version 4 deliberately adds:

```text
kernel/host distinction
symbolic predicates
symbolic transformations
planner
capability reporting
reference semantics
real utility
```

Therefore a larger total LOC estimate is not architectural failure.

The key constraint is:

\[
\boxed{
\text{Do not make the mathematical kernel grow with the number of adapters.}
}
\]

---

# 171. Adapter Growth

Adapters may grow independently:

```text
Verifier A
Verifier B
Verifier C
```

The core should remain stable.

This is a major architectural success criterion.

---

# 172. Haskell Style

The implementation should favor:

```text
ADTs
GADTs where semantically useful
newtypes for invariants
pure functions
pattern matching
guards
equational definitions
small modules
explicit error types
```

Point-free style is permitted where it improves mathematical clarity.

It should not be used as a compression contest.

---

# 173. Partial Functions

Avoid at semantic boundaries:

```haskell
head
tail
fromJust
read
!!
error
undefined
```

Prefer:

```haskell
Maybe
Either
NonEmpty
smart constructors
validated types
```

The rule is:

> Preconditions should either be encoded by types or discharged explicitly.

---

# 174. Laziness

Laziness is appropriate for:

```text
infinite enumeration
lazy candidate streams
fair interleaving
```

Strictness is appropriate at:

```text
counters
metrics
runtime state
worker coordination
I/O boundaries
```

Use measurement rather than ideology.

---

# 175. Concurrency

Concurrency is a runtime concern.

The mathematical specification contains no:

```text
ThreadId
MVar
STM
async
forkIO
```

unless a future semantic model explicitly proves that concurrency itself belongs in the language.

For the current experiment it does not.

---

# 176. Persistence

Persistence is runtime infrastructure.

The mathematical specification may be serializable.

A checkpoint is a persisted execution state.

These are different things.

---

# 177. Error Algebra

Errors should be typed.

Potential categories:

```text
SpecificationError
AnalysisError
PlanError
CheckpointError
VerificationError
RuntimeError
```

Avoid:

```haskell
String
```

as the universal error channel.

---

# 178. Error Semantics

A malformed specification is not:

```text
no solution
```

A verifier timeout is not:

```text
candidate rejected
```

A checkpoint mismatch is not:

```text
restart from zero silently
```

Semantic distinctions should survive all the way to the CLI.

---

# 179. CLI Output

Human output may be concise.

Machine output should eventually support:

```text
JSON
```

for automation.

The JSON representation should be derived from typed internal results.

It must not become the semantic source of truth.

---

# 180. Testing the Compiler

The planner should be tested as a compiler. The equation as originally
stated —

\[
\llbracket S\rrbracket = \llbracket plan(S)\rrbracket
\]

— is **not actually the planner's theorem**; it is the composition of
three independent theorems (§184) and silently assumes the fourth
(§185) as a hypothesis rather than stating it. Concretely: `plan(S)`'s
"semantic result" passes through a verifier, and if the verifier is
unsound (§185 — `Accepted(x)` does not imply `P(x)`), the equation is
simply false, no matter how correct the planner is. Stating it as an
unconditional identity therefore makes an unfalsifiable-looking claim
that is actually conditional. The precise, non-circular statement:

\[
\boxed{
\text{VerifierSound}(V) \ \wedge\ \text{PlannerCorrect}(plan)\ \wedge\ \text{RuntimeCorrect}(runtime)
\ \Longrightarrow\
\llbracket S\rrbracket = \llbracket plan(S)\rrbracket
}
\]

where each conjunct is independently defined and independently testable
(§184's three layers plus §185's fourth), and the compiler-correctness
test suite must exercise them **separately** — a passing end-to-end test
of the right-hand side alone cannot distinguish "the planner is correct"
from "the planner's bug happened to cancel the verifier's bug," which is
exactly the kind of false confidence §142 (trusted base) warns against.
This is the core compiler correctness property, correctly decomposed.

---

# 181. Optimization Correctness

For an optimization:

\[
opt(S)
\]

require:

\[
opt(S)\equiv_D S
\]

for denotationally preserving optimizations.

For operational transformations, require the stronger contract appropriate to the solver.

---

# 182. Planner Correctness

Planner correctness is stated **independently of verifier correctness**
(§185), per the §180 decomposition — conflating the two is the exact
circularity §180 now corrects. The planner's obligation is only:

```text
if plan returns Found x
then x belongs to the denotation ⟦S⟧,
and the plan submitted x to the declared verifier,
and the plan reports the verifier's actual Verification outcome
    (Accepted / Rejected / Failed, §30) unmodified.
```

"x is actually valid" is `VerifierSound(V) ⇒ Accepted(x) ⇒ P(x)` —
that implication belongs to §185, not here. A correct planner paired
with an unsound verifier correctly produces a wrong `Found x`; that is a
verifier-layer failure, not a planner-layer failure, and the two must
be diagnosable independently (§184).

For exhaustive search, `Exhausted` requires all completeness assumptions
(§22, §87) — this is a planner/enumeration-layer obligation and does not
involve the verifier's soundness, only its having been invoked on every
member of a completely-enumerated domain.

For canonical search, `FoundCanonical x proof` (§90) requires the
minimality proof obligation of §35/§37 to have actually been discharged
by the plan — not asserted — before the witness-carrying constructor may
be produced.

---

# 183. Runtime Correctness

The runtime is correct when it faithfully executes the plan.

This sounds obvious.

It is not.

The plan should be explicit enough that runtime correctness is separable from planning correctness.

---

# 184. The Three Proof Layers

The architecture naturally produces three correctness questions:

```text
SEMANTIC CORRECTNESS
    Does the expression mean what it claims?

PLANNING CORRECTNESS
    Does the plan preserve the requested semantics?

RUNTIME CORRECTNESS
    Does the runtime faithfully execute the plan?
```

This decomposition is one of the strongest reasons to use a compiler-like architecture.

---

# 185. Verification Correctness

There is a fourth:

```text
VERIFIER CORRECTNESS
    Does Accepted actually mean valid?
```

This is adapter-specific.

---

# 186. Overall Correctness

The end-to-end chain becomes:

\[
Specification
\rightarrow
Meaning
\rightarrow
Plan
\rightarrow
Execution
\rightarrow
Verification
\]

Each arrow has its own correctness contract.

That is much stronger than a monolithic “search algorithm”.

---

# 187. Research Vocabulary

The project should consistently use:

```text
syntax
denotation
interpretation
enumeration
predicate
order
analysis
planner
execution plan
runtime
verifier
capability
checkpoint
frontier
```

Avoid using one word such as “search” to mean all of these.

---

# 188. What “Search” Means

The word “search” should be reserved for the overall problem:

\[
\exists x\in D:P(x)
\]

or its solver interpretation.

It should not automatically mean:

```text
list traversal
thread pool
password loop
```

---

# 189. The Original Password Utility Reinterpreted

The original idea can now be stated precisely.

The application is:

> Enumerate a mathematically specified candidate language under a declared ordering and apply an authorized verifier until the requested semantic result is established.

That is much cleaner than:

> brute-force passwords.

The latter describes one operational technique.

The former describes the mathematical problem.

---

# 190. Why This Is a Better Experiment

The original utility is interesting because it combines:

```text
combinatorics
enumeration
ordering
verification
parallelism
checkpointing
external effects
```

It is therefore an unusually good stress test for a search calculus.

The utility is useful precisely because it forces the abstraction to become real.

---

# 191. The Utility Must Remain Real

Despite the mathematical focus, the project must deliver:

```text
installable executable
CLI
configuration
progress reporting
checkpointing
parallel execution
real verifier
tests
documentation
```

Otherwise the experiment risks becoming an academic datatype exercise.

---

# 192. The Research Must Remain Real

Conversely, the project must not become:

```text
CLI first
threads first
format adapters first
optimization first
```

with the mathematics written afterward.

The mathematical model must remain the source of the architecture.

---

# 193. The Balance

The project should therefore proceed as:

```text
THEORY
  ↓
REFERENCE IMPLEMENTATION
  ↓
REAL UTILITY
  ↓
OBSERVED LIMITATION
  ↓
THEORY REVISION
```

not:

```text
UTILITY
  ↓
DOCUMENTATION OF WHATEVER WAS WRITTEN
```

---

# 194. Design Principle

The strongest formulation is:

\[
\boxed{
\text{Build the utility as an interpreter of the abstraction.}
}
\]

Not:

\[
\text{Build the utility and abstract it afterward.}
\]

---

# 195. Final Architecture

The intended final architecture is:

```text
                 HUMAN / CONFIGURATION
                         │
                         ▼
                    FRONT-END DSL
                         │
                         ▼
                  TYPED SEARCH IR
                         │
             ┌───────────┼───────────┐
             │           │           │
             ▼           ▼           ▼
         SEMANTICS    ANALYSIS    NORMALIZATION
             │           │           │
             └───────────┼───────────┘
                         ▼
                       PLANNER
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
          SEQUENTIAL  PARALLEL  RESUMABLE
              │          │          │
              └──────────┼──────────┘
                         ▼
                       RUNTIME
                         │
                         ▼
                      VERIFIER
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
           FOUND     EXHAUSTED    FAILED
```

---

# 196. The Deepest Abstraction

The project should not assume that `AksharaExpr` is the final abstraction.

The real research objective is:

\[
\boxed{
\text{Find the smallest typed object from which the useful interpretations can be derived.}
}
\]

`AksharaExpr` is a candidate.

The experiment must be willing to replace it.

That is important.

---

# 197. Possible Future Generalization

The eventual object may turn out to be closer to:

```text
Typed Enumerable Language
```

than:

```text
AksharaExpr
```

The difference matters.

A search problem is then merely:

```text
Language
+
Predicate
+
Order
```

while many other computations become instances:

```text
generation
testing
optimization
enumeration
verification
exploration
```

---

# 198. Possible Algebraic Generalization

The kernel may eventually resemble:

\[
0,\;1,\;+\;,\;\times,\;\mu,\;map,\;filter
\]

with interpretations into:

```text
sets
sequences
multisets
streams
cost domains
probabilistic domains
execution plans
```

This should not be assumed in advance.

It should emerge from the experiment.

---

# 199. The Highest Useful Abstraction

The phrase “highest abstraction” needs one qualification.

The goal is not:

> maximum abstraction.

The goal is:

> **highest abstraction that remains mathematically precise, computationally interpretable, and capable of producing a useful program.**

An abstraction that cannot execute is incomplete for this experiment.

An implementation that cannot be explained mathematically is also incomplete.

---

# 200. Final Success Criterion

The strongest possible outcome is:

```text
A small mathematical language
        ↓
a precise denotational semantics
        ↓
a trusted reference interpreter
        ↓
multiple lawful operational interpretations
        ↓
a planner/compiler
        ↓
a real search utility
```

with the utility's core behavior derived rather than hand-coded.

---

# 201. Final Design Test

For every proposed abstraction ask:

1. What is its mathematical meaning?
2. What type invariant does it encode?
3. What are its algebraic laws?
4. What is its denotational interpretation?
5. What is its operational interpretation?
6. Does it preserve soundness?
7. Does it preserve completeness?
8. What are its productivity assumptions?
9. What are its fairness assumptions?
10. Can it be analyzed?
11. Can it be serialized?
12. Can it be partitioned?
13. Can it be resumed?
14. Can it be executed sequentially?
15. Can it be executed in parallel?
16. Can it support canonical search?
17. Can its correctness be tested against a reference semantics?
18. Does it materially help the real utility?

If the answers are unclear, the abstraction is not ready.

---

# 202. What Must Not Be Done

Do not:

- make passwords fundamental to the calculus;
- make file formats fundamental to the calculus;
- put threads into the mathematical syntax;
- equate sets with enumerations;
- equate cardinality with runtime;
- equate first result with canonical minimum;
- equate totality with termination;
- assume fairness without a theorem/contract;
- assume infinite products are automatically enumerable fairly;
- treat arbitrary Haskell functions as symbolic mathematics;
- promise universal checkpointing;
- use `Maybe` to represent every search outcome;
- hide verifier failure as rejection;
- hide exhaustion as failure;
- make the CLI the source of semantics;
- optimize before profiling;
- add abstractions merely because they are mathematically elegant;
- add type-level machinery merely because Haskell permits it.

---

# 203. Final Principle

The project should not make Haskell code **look mathematical**.

It should make the mathematics **determine the program structure**.

The final progression is:

```text
Question
   ↓
Mathematical specification
   ↓
Typed calculus
   ↓
Denotational semantics
   ↓
Operational semantics
   ↓
Analysis
   ↓
Planning
   ↓
Interpreter
   ↓
Runtime
   ↓
Real utility
```

The deepest statement of the experiment is:

\[
\boxed{
\text{The utility is an executable interpretation of the mathematics.}
}
\]

And the final engineering constraint is:

\[
\boxed{
\text{The mathematics must remain simpler than the utility it generates.}
}
\]

If the mathematical core becomes more complicated than the application, the abstraction has failed.

If the application becomes almost mechanical once the mathematical specification is correct, the abstraction has succeeded.

---

# Appendix A — Recommended First Repository Layout

```text
akshara/
├── app/
│   └── Main.hs
├── src/
│   ├── Akshara/
│   │   ├── Syntax.hs
│   │   ├── Domain.hs
│   │   ├── Transform.hs
│   │   ├── Predicate.hs
│   │   ├── Order.hs
│   │   ├── Semantics.hs
│   │   ├── Enumeration.hs
│   │   ├── Solver.hs
│   │   ├── Result.hs
│   │   ├── Partition.hs
│   │   ├── Plan.hs
│   │   └── Analysis/
│   │       ├── Cardinality.hs
│   │       ├── Finiteness.hs
│   │       ├── Bounds.hs
│   │       └── Cost.hs
│   ├── Runtime/
│   │   ├── Engine.hs
│   │   ├── Scheduler.hs
│   │   ├── Worker.hs
│   │   ├── Checkpoint.hs
│   │   └── Metrics.hs
│   ├── Verify/
│   │   ├── Class.hs
│   │   ├── Result.hs
│   │   └── Errors.hs
│   └── CLI/
│       ├── Parse.hs
│       ├── Command.hs
│       └── Render.hs
├── test/
│   ├── Reference/
│   ├── Algebra/
│   ├── Enumeration/
│   ├── Analysis/
│   ├── Planner/
│   ├── Runtime/
│   └── Integration/
├── examples/
│   └── ...
└── README.md
```

---

# Appendix B — First Concrete Deliverables

The project should produce these artifacts in order:

```text
1. Mathematical specification
2. Typed kernel
3. Reference semantics
4. Algebraic property suite
5. Finite enumerator
6. Fair infinite enumerator
7. Any-solution solver
8. Canonical solver
9. Analysis engine
10. Planner
11. Deterministic partitioner
12. Parallel runtime
13. Checkpoint engine
14. Verifier interface
15. First real verifier
16. CLI
17. First usable utility
```

---

# Appendix C — Definition of Done for Version 1

Version 1 is complete when:

```text
[ ] Kernel semantics are documented
[ ] Kernel types compile
[ ] Finite reference interpreter exists
[ ] Algebraic laws are property-tested
[ ] Enumeration is sound
[ ] Finite enumeration is complete
[ ] Infinite enumeration has explicit fairness assumptions
[ ] Any-solution search works
[ ] Canonical search has explicit order assumptions
[ ] Partition coverage/disjointness are tested
[ ] Sequential and parallel results agree
[ ] Checkpoint/resume agrees with uninterrupted execution
[ ] Verifier failure is distinct from rejection
[ ] One real verifier adapter exists
[ ] CLI can validate/analyze/plan/run
[ ] The utility works end-to-end
[ ] The mathematical core contains no application-specific format code
```

---

# Appendix D — The One Sentence to Preserve

If this document is reduced to one sentence, preserve this:

> **Build a small typed mathematical calculus of enumerable domains, then make the real utility a compiler/interpreter of that calculus so that the usefulness of the abstraction is demonstrated by execution rather than by explanation.**
