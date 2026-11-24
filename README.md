# Cluster Git: High-Performance Distributed Version Control System

> [!IMPORTANT]
> **Project Status: Active Development**  
> This project is currently under active development. Developers, researchers, and AI agents are invited to explore the codebase, test native builds, and contribute! See [Contribution Guidelines & Zero-Dependency Rule](#-contribution-guidelines--zero-dependency-rule) below.

**Author:** zk-mohammad <ZaidKhan-alamgir@proton.me>  
**Organization:** [cluster-lang](https://github.com/cluster-lang)  
**License:** Cluster Community & Fair-Source License (CCFL v1.0 / MIT-Conditional)  

---

## ⚡ Overview

Cluster Git is a standalone distributed version control system designed for speed, memory safety, and 100% two-way interoperability with official Git.

* **Binary Compatibility:** Full two-way interoperability with official `/usr/bin/git`. Objects, trees, commits, branches, and the `DIRC v2` index can be inspected and manipulated interchangeably.
* **Bare-Metal Speed:** Up to **2.38x faster** than official C Git on repository status queries.
* **Clean Architecture:** Fully implemented in pure Cluster across 7 modular files, eliminating the 400,000+ lines of historical C ceremony.

---

## 📊 Performance Benchmarks vs Official C Git

Benchmarked on Linux x86-64 across 50 iterations against official `/usr/bin/git`:

| Operation | Cluster Git (`cluster-git`) | Official Git (C) | Speedup |
| :--- | :--- | :--- | :--- |
| `git status` | **0.384 ms** | 0.913 ms | **⚡ 2.38x faster** |
| `git cat-file` | **0.642 ms** | 1.020 ms | **⚡ 1.59x faster** |
| `git log` | **0.751 ms** | 1.182 ms | **⚡ 1.57x faster** |
| Binary Size | **167 KB** | ~3.8 MB | **23x smaller** |

---

## 🛠️ Architecture & Modules

```
git/
├── bin/
│   └── cluster-git     # Standalone 167 KB native executable (LLVM -O3)
├── src/
│   ├── sha1.cl         # RFC 3174 SHA-1 Hashing Engine
│   ├── zlib.cl         # RFC 1950 Zlib Compression & Decompression
│   ├── object.cl       # Git Object Database (blobs, trees, commits, tags)
│   ├── index.cl        # DIRC v2 Binary Index Parser & Serializer
│   ├── repository.cl   # Repository Discovery & Ref Resolution (.git/refs)
│   ├── diff.cl         # Myers Diff Engine
│   └── main.cl         # Full Porcelain CLI Driver (init, status, add, commit, log, diff, branch, checkout)
└── tests/
    └── test_git.cl     # Comprehensive 10-Phase Automated Test Suite
```

---

## 🚀 Supported Commands

```bash
# Initialize a new repository
cluster-git init

# Check working tree status (2.38x faster than C Git)
cluster-git status

# Stage files into the index
cluster-git add src/main.cl

# Create a cryptographic commit
cluster-git commit -m "feat: initial commit"

# View commit history
cluster-git log

# Inspect repository diffs
cluster-git diff

# Branching & checking out
cluster-git branch feature
cluster-git checkout feature
```

---

## 🤝 Contribution Guidelines & Zero-Dependency Rule

The fundamental mission of **Cluster** is to eliminate external dependency bloat and provide a self-contained, high-performance ecosystem.

### Core Rules for Contributions:
1. **100% Pure Cluster (`.cl`):** All new features, plumbing commands, and porcelain tools must be written purely in Cluster.
2. **Zero Foreign Dependencies:** Absolutely no external C/C++ third-party library dependencies, no external header packages, and no platform-locked runtimes.
3. **Compiler-Only Execution:** Every program must compile and run using **only the Cluster compiler (`cluster`)** with zero external tooling requirements.
4. **Universal Device Portability:** Code must compile natively across all devices and architectures (x86-64, ARM64, embedded) with consistent deterministic behavior.

---

## 🧪 Automated Test Suite

Run the full 10-phase automated test suite:
```bash
cl run tests/test_git.cl
```

---

## 📜 License & Commercial Terms

This software is released under the **Cluster Community & Fair-Source License (CCFL v1.0 / MIT-Conditional)**:

- **100% Free for Independent & Research Use:**
  - Individual software developers, students, educators, academic researchers, non-profits, and scientific research groups have full rights to inspect, test, run, compile, and contribute without any license fees (any modification or derivative reproduction strictly requires prior written permission, including for research).
- **Commercial Enterprise License Required:**
  - For-profit companies, commercial startups, corporations, and enterprise businesses utilizing Cluster Git in commercial products, SaaS services, proprietary closed-source systems, or revenue-generating operations are required to purchase a commercial license.
  - Contact: **`ZaidKhan-alamgir@proton.me`** (`mohammadzaid/(cluster)`).
