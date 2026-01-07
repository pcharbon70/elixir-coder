# Phase 1: Data Collection & Preparation

## Overview

Phase 1 establishes the data foundation for training the Elixir LLM. By the end of this phase, we will have a comprehensive corpus of Elixir source code from Hex.pm packages and GitHub repositories, combined with ontology individuals from the elixir-ontologies project, all loaded into a quad-based knowledge graph with named graphs for efficient querying and multi-task training.

The design prioritizes data quality over quantity, recognizing that Elixir's smaller corpus compared to Python/JavaScript requires careful curation. We implement quality filters based on test coverage, documentation, Credo compliance, and recent maintenance activity. Ontology individuals provide semantic grounding for code entities, enabling the model to learn relationships between code constructs and their formal representations.

This phase uses the triple_store project (quad-based with named graphs) for efficient SPARQL querying, the `rdf` hex package for ontology parsing, and `elixir_ontologies` for working with ontology schemas.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Knowledge Graph Architecture                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│  Triple Store: Quads (Subject, Predicate, Object, Graph)                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Named Graphs by Source:                                                        │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │ graph:hex/                    (13,597 package versions)                    │  │
│  │   graph:hex/absinthe-1.9.0      → Module, Function, Type individuals    │  │
│  │   graph:hex/ecto-3.11.0          → Ecto-specific ontology individuals    │  │
│  │   graph:hex/phoenix-1.7.10       → Phoenix-specific individuals          │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │ graph:github/                 (GitHub repos)                               │  │
│  │   graph:github/phoenix_framework  → Repo-specific ontology individuals  │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │ graph:ontology/              (Core ontology schemas)                      │  │
│  │   graph:ontology/core         → elixir-core.ttl schema definitions      │  │
│  │   graph:ontology/structure     → elixir-structure.ttl definitions        │  │
│  │   graph:ontology/otp           → elixir-otp.ttl definitions              │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │ graph:train/val/test/        (Training splits)                            │  │
│  │   graph:train/package-N       → Training data for package N             │  │
│  │   graph:val/package-M         → Validation data for package M            │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│  Example SPARQL Query (graph-scoped):                                           │
│  SELECT ?module ?func WHERE {                                                      │
│    GRAPH graph:hex/absinthe-1.9.0 {                                             │
│      ?module a struct:Module .                                                  │
│      ?module struct:containsFunction ?func .                                     │
│      ?func struct:functionName "changeset" .                                     │
│    }                                                                              │
│  }                                                                                │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 1.0 Knowledge Graph Setup

- [ ] **Section 1.0 Complete**

This section establishes the quad-based knowledge graph infrastructure using the triple_store project. We load ontology schemas, Hex.pm package individuals, and training data into named graphs for efficient SPARQL querying and provenance tracking.

The quad store (Subject, Predicate, Object, Graph) enables package-level isolation, version tracking, and training split management while providing SPO/POS/OSP indices for fast pattern matching.

### 1.0.1 Triple Store Configuration

- [ ] **Task 1.0.1 Complete**

Configure triple_store as a dependency and initialize the knowledge graph database.

- [ ] 1.0.1.1 Add `{:triple_store, path: "../triple_store"}` to mix.exs dependencies
- [ ] 1.0.1.2 Implement `ElixirCoder.KnowledgeGraph.start_link/1` starting TripleStore process
- [ ] 1.0.1.3 Configure database path: `data/knowledge_graph/`
- [ ] 1.0.1.4 Enable quad mode with named graph support
- [ ] 1.0.1.5 Set up SPARQL endpoint for querying

### 1.0.2 Core Ontology Schema Loading

- [ ] **Task 1.0.2 Complete**

Load the core elixir-ontologies schema files into named graphs for reference during data loading and querying.

- [ ] 1.0.2.1 Implement `ElixirCoder.KnowledgeGraph.load_schemas/0`
- [ ] 1.0.2.2 Load `elixir-core.ttl` → `graph:ontology/core`
- [ ] 1.0.2.3 Load `elixir-structure.ttl` → `graph:ontology/structure`
- [ ] 1.0.2.4 Load `elixir-otp.ttl` → `graph:ontology/otp`
- [ ] 1.0.2.5 Load `elixir-evolution.ttl` → `graph:ontology/evolution`
- [ ] 1.0.2.6 Load `elixir-shapes.ttl` → `graph:ontology/shapes`
- [ ] 1.0.2.7 Verify schema graphs are queryable

### 1.0.3 Hex.pm Ontology Individuals Loading

- [ ] **Task 1.0.3 Complete**

Load all 13,597 Hex.pm package ontology individuals from `../elixir-ontologies/.ttl/` into named graphs.

- [ ] 1.0.3.1 Implement `ElixirCoder.KnowledgeGraph.load_hex_individuals/1`
- [ ] 1.0.3.2 Scan `../elixir-ontologies/.ttl/` directory for `*.ttl` files
- [ ] 1.0.3.3 Parse filename: `{package}-{version}.ttl` → graph name: `graph:hex/{package}-{version}`
- [ ] 1.0.3.4 Load each TTL file into its named graph using `TripleStore.load_files/2`
- [ ] 1.0.3.5 Implement parallel loading with configurable batch size
- [ ] 1.0.3.6 Track loading progress: `Telemetry.attach("kg:load:progress")`
- [ ] 1.0.3.7 Create graph metadata index: package → versions, version → graph
- [ ] 1.0.3.8 Target: Load all 13,597 files (73.8M triples)

### 1.0.4 Graph Metadata Management

- [ ] **Task 1.0.4 Complete**

Implement metadata tracking for named graphs to enable efficient querying and management.

- [ ] 1.0.4.1 Implement `ElixirCoder.KnowledgeGraph.register_graph/2`
- [ ] 1.0.4.2 Store graph metadata: source, package, version, timestamp, triple_count
- [ ] 1.0.4.3 Create `graph:metadata` index for graph discovery
- [ ] 1.0.4.4 Implement `ElixirCoder.KnowledgeGraph.list_graphs/1` filtering by prefix
- [ ] 1.0.4.5 Implement `ElixirCoder.KnowledgeGraph.graph_info/1` returning metadata
- [ ] 1.0.4.6 Implement `ElixirCoder.KnowledgeGraph.delete_graph/1` for removal

### 1.0.5 Incremental Loading

- [ ] **Task 1.0.5 Complete**

Support incremental loading of new packages without rebuilding the entire knowledge graph.

- [ ] 1.0.5.1 Implement `ElixirCoder.KnowledgeGraph.add_package/2` for new package versions
- [ ] 1.0.5.2 Check for existing versions of the same package
- [ ] 1.0.5.3 Archive old graph: `graph:hex/{package}-{old_version}` → `graph:archive/hex/{package}-{old_version}`
- [ ] 1.0.5.4 Load new version into `graph:hex/{package}-{new_version}`
- [ ] 1.0.5.5 Update graph metadata index
- [ ] 1.0.5.6 Implement `ElixirCoder.KnowledgeGraph.sync_from_elixir_ontologies/0`

### 1.0.6 Unit Tests

- [ ] **Task 1.0.6 Complete**

- [ ] Test triple_store starts and stops cleanly
- [ ] Test schema graphs load and are queryable
- [ ] Test Hex individual loading creates correct named graphs
- [ ] Test graph metadata stores and retrieves correctly
- [ ] Test incremental loading adds new graphs without affecting existing
- [ ] Test SPARQL queries work across named graphs

---

## 1.1 Ontology Schema Integration

- [ ] **Section 1.1 Complete**

This section integrates the elixir-ontologies schema definitions, providing the vocabulary and class definitions for all ontology individuals. These schemas define what properties and relationships exist for modules, functions, types, and OTP patterns.

We use the elixir_ontologies package to access schema definitions and validate that loaded individuals conform to expected patterns.

### 1.1.1 Schema Access via ElixirOntologies

- [ ] **Task 1.1.1 Complete**

Access core ontology schemas through the elixir_ontologies package.

- [ ] 1.1.1.1 Use `ElixirOntologies.ontology_path/1` for schema file access
- [ ] 1.1.1.2 Load schemas into `graph:ontology/*` named graphs
- [ ] 1.1.1.3 Implement `ElixirCoder.Ontology.Schema.list_classes/1` returning all classes for a graph
- [ ] 1.1.1.4 Implement `ElixirCoder.Ontology.Schema.list_properties/1` returning all properties
- [ ] 1.1.1.5 Cache schema definitions in `:persistent_term` for fast access

### 1.1.2 Schema Validation

- [ ] **Task 1.1.2 Complete**

Validate that loaded ontology individuals conform to schema definitions.

- [ ] 1.1.2.1 Implement `ElixirCoder.Ontology.Schema.validate_graph/2`
- [ ] 1.1.2.2 Check that all individuals have required properties
- [ ] 1.1.2.3 Validate property values against datatype constraints
- [ ] 1.1.2.4 Use SHACL shapes from `elixir-shapes.ttl` for validation
- [ ] 1.1.2.5 Report validation errors with graph name and individual IRI

### 1.1.3 Triple Linearization Templates

- [ ] **Task 1.1.3 Complete**

Create templates for linearizing ontology quads into text format for training.

- [ ] 1.1.3.1 Define `ElixirCoder.Ontology.Linearizer.template/2` for module-level annotations
- [ ] 1.1.3.2 Define templates for function-level annotations (callback patterns, type signatures)
- [ ] 1.1.3.3 Define templates for behaviour requirements (required callbacks, optional callbacks)
- [ ] 1.1.3.4 Define templates for type relationships (subtype, dependency, usage)
- [ ] 1.1.3.5 Implement `ElixirCoder.Ontology.Linearizer.linearize_quad/2` converting quad to text
- [ ] 1.1.3.6 Support multi-hop traversal for related individuals

### 1.1.4 Unit Tests

- [ ] **Task 1.1.4 Complete**

- [ ] Test schema access returns correct class/property lists
- [ ] Test validation catches malformed individuals
- [ ] Test linearization produces valid text format
- [ ] Test multi-hop traversal includes related entities

---

## 1.2 Hex.pm Package Scraping

- [ ] **Section 1.2 Complete**

This section implements scraping of Hex.pm packages to build the primary Elixir source code corpus. Hex.pm contains ~17,000 packages representing the majority of public Elixir code, providing high-quality, well-tested examples of idiomatic Elixir.

We prioritize packages by download count, stars, and recent updates to ensure relevance. Each package is downloaded, extracted, and validated for inclusion in the training corpus.

### 1.2.1 Hex API Client

- [ ] **Task 1.2.1 Complete**

Implement a client for the Hex.pm API to enumerate packages and retrieve metadata.

- [ ] 1.2.1.1 Implement `ElixirCoder.Data.Hex.package_list/1` with pagination support
- [ ] 1.2.1.2 Implement `ElixirCoder.Data.Hex.package_info/1` returning package metadata
- [ ] 1.2.1.3 Implement `ElixirCoder.Data.Hex.package_releases/1` returning version history
- [ ] 1.2.1.4 Implement `ElixirCoder.Data.Hex.package_dependencies/2` returning dependency tree
- [ ] 1.2.1.5 Add request throttling and retry logic with exponential backoff
- [ ] 1.2.1.6 Cache API responses locally to minimize redundant requests

### 1.2.2 Package Download

- [ ] **Task 1.2.2 Complete**

Implement downloading and extraction of Hex.pm tarballs, saving source code to the raw data directory.

- [ ] 1.2.2.1 Implement `ElixirCoder.Data.Hex.download_tarball/2` downloading from repo.hex.pm
- [ ] 1.2.2.2 Implement `ElixirCoder.Data.Hex.extract_tarball/2` extracting to `data/raw/hex/`
- [ ] 1.2.2.3 Implement checksum verification to ensure download integrity
- [ ] 1.2.2.4 Handle symlinks and special file types appropriately
- [ ] 1.2.2.5 Track download progress via Telemetry events
- [ ] 1.2.2.6 Implement resume capability for interrupted downloads

### 1.2.3 Package Quality Filtering

- [ ] **Task 1.2.3 Complete**

Implement quality filters to exclude low-quality packages from the training corpus, ensuring only well-maintained, well-tested code is included.

- [ ] 1.2.3.1 Implement `ElixirCoder.Data.Hex.has_tests?/1` checking for `test/` directory
- [ ] 1.2.3.2 Implement `ElixirCoder.Data.Hex.has_docs?/1` checking for documentation
- [ ] 1.2.3.3 Implement `ElixirCoder.Data.Hex.recently_updated?/2` checking last release date
- [ ] 1.2.3.4 Implement `ElixirCoder.Data.Hex.meets_downloads?/2` filtering by download count
- [ ] 1.2.3.5 Implement `ElixirCoder.Data.Hex.quality_score/1` computing composite score
- [ ] 1.2.3.6 Define threshold: downloads > 1000 OR stars > 5, updated within 2 years

### 1.2.4 Batch Scraping Pipeline

- [ ] **Task 1.2.4 Complete**

Implement the orchestrated pipeline for bulk downloading Hex.pm packages with progress tracking and error handling.

- [ ] 1.2.4.1 Implement `ElixirCoder.Data.Hex.scrape_all/1` with configurable concurrency
- [ ] 1.2.4.2 Implement parallel downloading using `Task.async_stream`
- [ ] 1.2.4.3 Implement error isolation (one package failure doesn't stop others)
- [ ] 1.2.4.4 Implement checkpoint/resume capability for long-running scrapes
- [ ] 1.2.4.5 Create `data/raw/hex/manifest.json` tracking downloaded packages
- [ ] 1.2.4.6 Implement summary statistics: total packages, total bytes, failed downloads

### 1.2.5 License Filtering

- [ ] **Task 1.2.5 Complete**

Implement license detection and filtering to exclude packages with restrictive licenses that may complicate model distribution.

- [ ] 1.2.5.1 Implement `ElixirCoder.Data.Hex.detect_license/1` parsing `mix.exs` license field
- [ ] 1.2.5.2 Implement `ElixirCoder.Data.Hex.permissive_license?/1` checking against allowlist
- [ ] 1.2.5.3 Allowlist: Apache-2.0, MIT, BSD-2-Clause, BSD-3-Clause, ISC, EPL-1.0
- [ ] 1.2.5.4 Exclude: GPL, AGPL, SSPL, proprietary
- [ ] 1.2.5.5 Flag unknown licenses for manual review

### 1.2.6 Unit Tests

- [ ] **Task 1.2.6 Complete**

- [ ] Test Hex API client returns valid package metadata
- [ ] Test tarball download produces valid archive
- [ ] Test extraction produces correct directory structure
- [ ] Test quality filters exclude/include correctly
- [ ] Test license detection identifies common licenses
- [ ] Test batch pipeline handles errors gracefully
- [ ] Test resume capability restores from checkpoint

---

## 1.3 GitHub Repository Scraping

- [ ] **Section 1.3 Complete**

This section implements scraping of Elixir repositories from GitHub to supplement the Hex.pm corpus with application code, examples, and projects not published as packages.

We use GitHub's search API to find repositories filtered by language and stars, then clone them using git. Quality filters ensure we collect relevant, high-quality Elixir code.

### 1.3.1 GitHub API Client

- [ ] **Task 1.3.1 Complete**

Implement a client for GitHub's search and repository APIs.

- [ ] 1.3.1.1 Implement `ElixirCoder.Data.GitHub.search_repos/2` with language:elixir filter
- [ ] 1.3.1.2 Implement `ElixirCoder.Data.GitHub.repo_info/1` returning repository metadata
- [ ] 1.3.1.3 Implement authentication via GitHub token for rate limit increases
- [ ] 1.3.1.4 Implement rate limit handling and retry logic
- [ ] 1.3.1.5 Cache responses locally to minimize API usage

### 1.3.2 Repository Cloning

- [ ] **Task 1.3.2 Complete**

Implement git-based cloning of repositories with shallow clone for efficiency.

- [ ] 1.3.2.1 Implement `ElixirCoder.Data.GitHub.clone_repo/2` cloning to `data/raw/github/`
- [ ] 1.3.2.2 Use `--depth 1 --single-branch` for minimal clone size
- [ ] 1.3.2.3 Implement `ElixirCoder.Data.GitHub.fetch_updates/2` updating existing clones
- [ ] 1.3.2.4 Handle authentication for private repositories if configured
- [ ] 1.3.2.5 Track clone progress via Telemetry

### 1.3.3 Repository Quality Filtering

- [ ] **Task 1.3.3 Complete**

Implement quality filters for GitHub repositories, focusing on active, maintained projects with meaningful code.

- [ ] 1.3.3.1 Implement `ElixirCoder.Data.GitHub.star_filter/2` minimum stars threshold
- [ ] 1.3.3.2 Implement `ElixirCoder.Data.GitHub.active_development?/2` checking recent commits
- [ ] 1.3.3.3 Implement `ElixirCoder.Data.GitHub.meaningful_size?/1` filtering tiny/troll repos
- [ ] 1.3.3.4 Implement `ElixirCoder.Data.GitHub.has_elixir_code?/1` verifying .ex files
- [ ] 1.3.3.5 Define thresholds: stars >= 5, commit within 1 year, > 100 lines of code

### 1.3.4 Batch Scraping Pipeline

- [ ] **Task 1.3.4 Complete**

Implement the orchestrated pipeline for bulk cloning GitHub repositories.

- [ ] 1.3.4.1 Implement `ElixirCoder.Data.GitHub.scrape_all/1` with pagination
- [ ] 1.3.4.2 Implement parallel cloning with configurable concurrency
- [ ] 1.3.4.3 Implement checkpoint/resume for interrupted runs
- [ ] 1.3.4.4 Create `data/raw/github/manifest.json` tracking cloned repos
- [ ] 1.3.4.5 Implement deduplication against Hex.pm packages (by URL)

### 1.3.5 Unit Tests

- [ ] **Task 1.3.5 Complete**

- [ ] Test GitHub API client handles pagination
- [ ] Test repository cloning produces valid git checkout
- [ ] Test quality filters apply correctly
- [ ] Test batch pipeline handles network errors
- [ ] Test deduplication identifies duplicate sources

---

## 1.4 Code-Test Pair Extraction

- [ ] **Section 1.4 Complete**

This section extracts paired code and test files from the scraped corpus, establishing the foundation for test generation training. For each source file, we locate corresponding test files and create pairs for supervised training.

We handle various test file naming conventions (e.g., `my_module.ex` -> `my_module_test.exs`) and support both ExUnit unit tests and property-based tests.

### 1.4.1 File Discovery

- [ ] **Task 1.4.1 Complete**

Implement discovery of source and test files within downloaded packages/repos.

- [ ] 1.4.1.1 Implement `ElixirCoder.Data.Discovery.find_source_files/1` scanning for `lib/**/*.ex`
- [ ] 1.4.1.2 Implement `ElixirCoder.Data.Discovery.find_test_files/1` scanning for `test/**/*.exs`
- [ ] 1.4.1.3 Implement `ElixirCoder.Data.Discovery.find_support_files/1` finding `test/support/**/*.ex`
- [ ] 1.4.1.4 Ignore `mix.exs`, `config/*.exs`, and other non-library files
- [ ] 1.4.1.5 Filter out generated files (e.g., `*_web.ex` generated by Phoenix)

### 1.4.2 Pair Matching

- [ ] **Task 1.4.2 Complete**

Implement matching of source files to their corresponding test files using naming conventions.

- [ ] 1.4.2.1 Implement `ElixirCoder.Data.Pairing.find_test_for_source/2` using convention
- [ ] 1.4.2.2 Implement `ElixirCoder.Data.Pairing.find_source_for_test/2` reverse lookup
- [ ] 1.4.2.3 Handle `MyApp.Web` -> `MyAppWebTest` Phoenix convention
- [ ] 1.4.2.4 Handle namespace nesting (e.g., `MyApp/Sub/Module` -> `MyApp.Sub.ModuleTest`)
- [ ] 1.4.2.5 Return `{:matched, source, test}` or `{:unmatched, source}` tuples

### 1.4.3 Pair Extraction

- [ ] **Task 1.4.3 Complete**

Implement extraction of paired code and test content, including metadata.

- [ ] 1.4.3.1 Implement `ElixirCoder.Data.Pairing.extract_pair/2` reading file contents
- [ ] 1.4.3.2 Extract module name from source using `Code.string_to_quoted/1`
- [ ] 1.4.3.3 Extract test module name and describe blocks from test file
- [ ] 1.4.3.4 Record metadata: file paths, line counts, function definitions
- [ ] 1.4.3.5 Store as `ElixirCoder.Data.Pair` struct

### 1.4.4 Batch Pair Extraction

- [ ] **Task 1.4.4 Complete**

Implement batch processing of all downloaded packages/repos to extract pairs.

- [ ] 1.4.4.1 Implement `ElixirCoder.Data.Pairing.extract_from_package/2` processing one package
- [ ] 1.4.4.2 Implement `ElixirCoder.Data.Pairing.extract_from_corpus/1` processing all
- [ ] 1.4.4.3 Create `data/processed/pairs.jsonl` with one pair per line
- [ ] 1.4.4.4 Generate summary statistics: total pairs, matched percentage
- [ ] 1.4.4.5 Report unmatched sources (code without tests)

### 1.4.5 Unit Tests

- [ ] **Task 1.4.5 Complete**

- [ ] Test file discovery finds all expected files
- [ ] Test pair matching handles standard conventions
- [ ] Test pair matching handles Phoenix conventions
- [ ] Test pair extraction produces valid structs
- [ ] Test batch extraction produces valid JSONL output

---

## 1.5 Ontology Augmentation via SPARQL

- [ ] **Section 1.5 Complete**

This section annotates extracted code with ontology information from the knowledge graph, using SPARQL queries to retrieve relevant individuals from named graphs. For each function, module, and type, we query the knowledge graph and generate text annotations.

### 1.5.1 AST-Based Entity Extraction

- [ ] **Task 1.5.1 Complete**

Implement extraction of code entities from parsed AST for ontology lookup.

- [ ] 1.5.1.1 Implement `ElixirCoder.Annotation.Extractor.extract_modules/1`
- [ ] 1.5.1.2 Implement `ElixirCoder.Annotation.Extractor.extract_functions/1`
- [ ] 1.5.1.3 Implement `ElixirCoder.Annotation.Extractor.extract_types/1`
- [ ] 1.5.1.4 Implement `ElixirCoder.Annotation.Extractor.extract_behaviours/1`
- [ ] 1.5.1.5 Implement `ElixirCoder.Annotation.Extractor.extract_calls/1` for usage relationships
- [ ] 1.5.1.6 Return structured entity list with line numbers and metadata

### 1.5.2 SPARQL-Based Ontology Lookup

- [ ] **Task 1.5.2 Complete**

Implement SPARQL queries against named graphs to find ontology individuals.

- [ ] 1.5.2.1 Implement `ElixirCoder.Annotation.Lookup.query_module/2` querying all hex graphs
- [ ] 1.5.2.2 Implement `ElixirCoder.Annotation.Lookup.query_function/4` by module/name/arity
- [ ] 1.5.2.3 Implement `ElixirCoder.Annotation.Lookup.query_behaviour/2` by behaviour name
- [ ] 1.5.2.4 Implement `ElixirCoder.Annotation.Lookup.query_type/2` by type name
- [ ] 1.5.2.5 Support graph-scoped queries: `GRAPH graph:hex/{package}-{version} { ... }`
- [ ] 1.5.2.6 Support union queries across multiple package versions
- [ ] 1.5.2.7 Cache frequently queried individuals in `:ets` tables

### 1.5.3 Linearization

- [ ] **Task 1.5.3 Complete**

Implement conversion of ontology individuals to linearized text format for training.

- [ ] 1.5.3.1 Implement `ElixirCoder.Annotation.Linearizer.linearize_module/2`
- [ ] 1.5.3.2 Implement `ElixirCoder.Annotation.Linearizer.linearize_function/2`
- [ ] 1.5.3.3 Implement `ElixirCoder.Annotation.Linearizer.linearize_behaviour/2`
- [ ] 1.5.3.4 Implement `ElixirCoder.Annotation.Linearizer.linearize_type/2`
- [ ] 1.5.3.5 Use format: `[ONTO] <predicate>object</predicate> [/ONTO]`
- [ ] 1.5.3.6 Support multi-hop annotations (include related individuals)

### 1.5.4 Code Annotation Pipeline

- [ ] **Task 1.5.4 Complete**

Implement end-to-end annotation pipeline for code-test pairs.

- [ ] 1.5.4.1 Implement `ElixirCoder.Annotation.annotate_code/2` for source code
- [ ] 1.5.4.2 Implement `ElixirCoder.Annotation.annotate_test/2` for test code
- [ ] 1.5.4.3 Implement `ElixirCoder.Annotation.annotate_pair/2` for pairs
- [ ] 1.5.4.4 Create interleaved format: `[CODE]...[/CODE] [ONTO]...[/ONTO]`
- [ ] 1.5.4.5 Store annotated pairs to `data/processed/annotated.jsonl`

### 1.5.5 Unit Tests

- [ ] **Task 1.5.5 Complete**

- [ ] Test AST extraction finds all defined entities
- [ ] Test SPARQL queries return correct individuals from named graphs
- [ ] Test linearization produces valid format
- [ ] Test annotation pipeline preserves original code
- [ ] Test multi-hop annotations include related entities

---

## 1.6 Credo Annotation

- [ ] **Section 1.6 Complete**

This section generates Credo-based quality annotations for training data, creating contrastive pairs (clean vs. violating code) for quality-aware training.

We run Credo on source files and annotate functions with the checks they violate, enabling the model to learn quality patterns through supervised learning.

### 1.6.1 Credo Execution

- [ ] **Task 1.6.1 Complete**

Implement programmatic execution of Credo on source files.

- [ ] 1.6.1.1 Implement `ElixirCoder.Quality.Credo.run_on_file/1`
- [ ] 1.6.1.2 Implement `ElixirCoder.Quality.Credo.parse_output/1` parsing JSON output
- [ ] 1.6.1.3 Use `mix credo --format json` for structured results
- [ ] 1.6.1.4 Map issues to specific functions via line numbers
- [ ] 1.6.1.5 Handle timeout for long-running analysis

### 1.6.2 Issue Mapping

- [ ] **Task 1.6.2 Complete**

Implement mapping of Credo issues to code entities for annotation.

- [ ] 1.6.2.1 Implement `ElixirCoder.Quality.Credo.group_issues_by_function/1`
- [ ] 1.6.2.2 Implement `ElixirCoder.Quality.Credo.check_for_function/2`
- [ ] 1.6.2.3 Categorize issues by Credo's 5 categories (Consistency, Design, Readability, Refactor, Warning)
- [ ] 1.6.2.4 Create clean/violating label for each function

### 1.6.3 Contrastive Pair Generation

- [ ] **Task 1.6.3 Complete**

Implement generation of contrastive training pairs by injecting Credo violations.

- [ ] 1.6.3.1 Implement `ElixirCoder.Quality.Pairs.generate_for_function/2`
- [ ] 1.6.3.2 Implement violation injection for common issues (IO.inspect, nesting, etc.)
- [ ] 1.6.3.3 Create triples: `{clean_code, violating_code, violation_type}`
- [ ] 1.6.3.4 Store to `data/processed/credo_pairs.jsonl`

### 1.6.4 Unit Tests

- [ ] **Task 1.6.4 Complete**

- [ ] Test Credo execution produces valid JSON
- [ ] Test issue mapping groups by function correctly
- [ ] Test contrastive generation creates valid pairs
- [ ] Test violation injection creates realistic violations

---

## 1.7 Sobelow Annotation

- [ ] **Section 1.7 Complete**

This section generates Sobelow-based security annotations for Phoenix/web code, creating vulnerability-labeled training data for security-aware model training.

### 1.7.1 Sobelow Execution

- [ ] **Task 1.7.1 Complete**

Implement programmatic execution of Sobelow on Phoenix projects.

- [ ] 1.7.1.1 Implement `ElixirCoder.Security.Sobelow.run_on_project/1`
- [ ] 1.7.1.2 Implement `ElixirCoder.Security.Sobelow.parse_output/1` parsing JSON
- [ ] 1.7.1.3 Use `mix sobelow --format json --exit` for structured results
- [ ] 1.7.1.4 Map findings to specific functions via file paths and line numbers

### 1.7.2 CWE Mapping

- [ ] **Task 1.7.2 Complete**

Implement mapping of Sobelow checks to CWE identifiers.

- [ ] 1.7.2.1 Define `ElixirCoder.Security.Sobelow.cwe_mapping/0` mapping check -> CWE
- [ ] 1.7.2.2 Include all 30+ Sobelow checks with CWE mappings
- [ ] 1.7.2.3 Support multiple CWEs per check where applicable
- [ ] 1.7.2.4 Map CWE categories to training labels

### 1.7.3 Vulnerability Pair Generation

- [ ] **Task 1.7.3 Complete**

Implement generation of secure/vulnerable code pairs for contrastive learning.

- [ ] 1.7.3.1 Implement `ElixirCoder.Security.Pairs.generate_for_function/2`
- [ ] 1.7.3.2 Implement vulnerability injection (SQLi, XSS, etc.)
- [ ] 1.7.3.3 Create triples: `{secure_code, vulnerable_code, cwe_id}`
- [ ] 1.7.3.4 Store to `data/processed/sobelow_pairs.jsonl`

### 1.7.4 Unit Tests

- [ ] **Task 1.7.4 Complete**

- [ ] Test Sobelow execution produces valid JSON
- [ ] Test CWE mapping covers all Sobelow checks
- [ ] Test vulnerability pairs represent actual security issues

---

## 1.8 Dataset Assembly with Named Graphs

- [ ] **Section 1.8 Complete**

This section assembles the final training dataset from all annotated sources, creating balanced splits using named graphs for train/val/test separation.

### 1.8.1 Dataset Schema Definition

- [ ] **Task 1.8.1 Complete**

Define the schema for training examples encompassing all task types.

- [ ] 1.8.1.1 Define `ElixirCoder.Dataset.Schema` struct with fields:
- [ ] 1.8.1.2 Fields: id, code, test, ontology_annotation, credo_issues, sobelow_findings
- [ ] 1.8.1.3 Add metadata: source, graph_iri, language, license, timestamp
- [ ] 1.8.1.4 Define JSON encoding/decoding

### 1.8.2 Train/Val/Test Split with Named Graphs

- [ ] **Task 1.8.2 Complete**

Implement dataset splitting using named graphs for isolation.

- [ ] 1.8.2.1 Implement `ElixirCoder.Dataset.Split.create_split_graphs/3` (80/10/10)
- [ ] 1.8.2.2 Create `graph:train/{package}`, `graph:val/{package}`, `graph:test/{package}`
- [ ] 1.8.2.3 Copy quads from source graphs to split graphs (no data duplication at quad level)
- [ ] 1.8.2.4 Ensure all files from same package go to same split
- [ ] 1.8.2.5 Implement stratified sampling for balanced representation
- [ ] 1.8.2.6 Create split manifests: `graph:metadata/train`, `graph:metadata/val`, `graph:metadata/test`

### 1.8.3 Statistics and Analysis

- [ ] **Task 1.8.3 Complete**

Compute and report dataset statistics using SPARQL queries.

- [ ] 1.8.3.1 Implement `ElixirCoder.Dataset.Stats.compute/1` with graph filter
- [ ] 1.8.3.2 Query: total examples, tokens, functions, modules per split
- [ ] 1.8.3.3 Query: Credo violation distribution by category
- [ ] 1.8.3.4 Query: Sobelow finding distribution by CWE
- [ ] 1.8.3.5 Query: Ontology coverage percentage by graph
- [ ] 1.8.3.6 Create `data/processed/stats.json`

### 1.8.4 Unit Tests

- [ ] **Task 1.8.4 Complete**

- [ ] Test dataset schema encodes/decodes correctly
- [ ] Test split graphs contain correct data
- [ ] Test split has no package leakage across graphs
- [ ] Test statistics queries return accurate counts
- [ ] Test all splits have balanced distributions

---

## Success Criteria

1. **Knowledge Graph**: 13,597 Hex.pm packages loaded into named graphs
2. **Corpus Size**: 50GB+ of processed Elixir source code
3. **Code-Test Pairs**: 10,000+ annotated pairs
4. **Ontology Coverage**: 60%+ of functions mapped to ontology individuals via SPARQL
5. **Quality Labels**: Credo annotations for all source files
6. **Security Labels**: Sobelow annotations for all web code
7. **Dataset Balance**: Named graphs for train/val/test with no package leakage

## Provides Foundation

This phase establishes the data for:
- **Phase 2**: Source code trains custom tokenizer
- **Phase 3**: Annotated examples inform architecture design
- **Phase 4**: Knowledge graph queries feed training pipeline
- **Phase 5**: Labels enable multi-task training
