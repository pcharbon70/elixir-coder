# Phase 1: Data Collection & Preparation

## Overview

Phase 1 establishes the data foundation for training the Elixir LLM. By the end of this phase, we will have a comprehensive corpus of Elixir source code from Hex.pm packages and GitHub repositories, combined with ontology individuals from the elixir-ontologies project, all processed and annotated for multi-task training.

The design prioritizes data quality over quantity, recognizing that Elixir's smaller corpus compared to Python/JavaScript requires careful curation. We implement quality filters based on test coverage, documentation, Credo compliance, and recent maintenance activity. Ontology individuals provide semantic grounding for code entities, enabling the model to learn relationships between code constructs and their formal representations.

This phase integrates with the existing RDF/OWL ecosystem using the `rdf` hex package for ontology parsing and manipulation.

---

## 1.1 Ontology Integration

- [ ] **Section 1.1 Complete**

This section loads and processes the elixir-ontologies TTL files to extract individual entities that will ground the code generation model in formal semantics. Ontologies provide type information, behavioral patterns, and structural relationships that pure code corpora lack.

We use RDF.ex to parse TTL files and extract individuals representing modules, functions, types, and OTP patterns. These individuals are indexed for efficient lookup during training data annotation.

### 1.1.1 Ontology Download and Storage

- [ ] **Task 1.1.1 Complete**

Download and store the elixir-ontologies TTL files from the GitHub repository, establishing the local canonical copy for all downstream processing.

- [ ] 1.1.1.1 Clone https://github.com/pcharbon70/elixir-ontologies to `data/ontologies/`
- [ ] 1.1.1.2 Verify all four core TTL files: `elixir-core.ttl`, `elixir-otp.ttl`, `elixir-structure.ttl`, `elixir-shapes.ttl`
- [ ] 1.1.1.3 Compute SHA256 hashes for integrity verification
- [ ] 1.1.1.4 Create `data/ontologies/versions.json` tracking ontology versions and timestamps

### 1.1.2 TTL File Parsing

- [ ] **Task 1.1.2 Complete**

Parse TTL files using RDF.ex to extract triples and build an in-memory representation suitable for querying and annotation.

- [ ] 1.1.2.1 Implement `ElixirCoder.Ontology.Loader.load_file/1` returning `RDF.Graph.t()`
- [ ] 1.1.2.2 Implement `ElixirCoder.Ontology.Loader.load_all/0` loading all four TTL files
- [ ] 1.1.2.3 Implement `ElixirCoder.Ontology.Loader.merge_graphs/1` combining graphs
- [ ] 1.1.2.4 Add progress tracking via Telemetry events for large graph parsing
- [ ] 1.1.2.5 Handle parse errors with detailed reporting of file/line/location

### 1.1.3 Individual Extraction

- [ ] **Task 1.1.3 Complete**

Extract individual entities from ontology graphs, categorizing them by type (modules, functions, behaviours, types, patterns) for efficient lookup during training annotation.

- [ ] 1.1.3.1 Implement `ElixirCoder.Ontology.Individuals.extract_modules/1` returning module individuals
- [ ] 1.1.3.2 Implement `ElixirCoder.Ontology.Individuals.extract_functions/1` returning function individuals
- [ ] 1.1.3.3 Implement `ElixirCoder.Ontology.Individuals.extract_behaviours/1` returning OTP behaviour individuals
- [ ] 1.1.3.4 Implement `ElixirCoder.Ontology.Individuals.extract_types/1` returning type individuals
- [ ] 1.1.3.5 Implement `ElixirCoder.Ontology.Individuals.extract_patterns/1` returning pattern individuals
- [ ] 1.1.3.6 Implement `ElixirCoder.Ontology.Individuals.by_name/2` for lookup by entity name

### 1.1.4 Triple Linearization Templates

- [ ] **Task 1.1.4 Complete**

Create templates for linearizing ontology triples into text format that can be interleaved with code during training.

- [ ] 1.1.4.1 Define `ElixirCoder.Ontology.Linearizer.template/2` for module-level annotations
- [ ] 1.1.4.2 Define templates for function-level annotations (callback patterns, type signatures)
- [ ] 1.1.4.3 Define templates for behaviour requirements (required callbacks, optional callbacks)
- [ ] 1.1.4.4 Define templates for type relationships (subtype, dependency, usage)
- [ ] 1.1.4.5 Implement `ElixirCoder.Ontology.Linearizer.linearize/2` converting individual to text
- [ ] 1.1.4.6 Support multi-hop traversal for related individuals (e.g., module -> callbacks -> types)

### 1.1.5 Index Construction

- [ ] **Task 1.1.5 Complete**

Build in-memory and persistent indices mapping code entities to their ontology representations, enabling fast lookup during dataset annotation.

- [ ] 1.1.5.1 Implement `ElixirCoder.Ontology.Index.build/1` creating inverted index
- [ ] 1.1.5.2 Create `:ets` table for module name -> ontology individual mapping
- [ ] 1.1.5.3 Create `:ets` table for function {module, name, arity} -> ontology mapping
- [ ] 1.1.5.4 Create `:ets` table for type name -> ontology individual mapping
- [ ] 1.1.5.5 Implement `ElixirCoder.Ontology.Index.lookup_module/2`
- [ ] 1.1.5.6 Implement `ElixirCoder.Ontology.Index.lookup_function/3`
- [ ] 1.1.5.7 Implement `ElixirCoder.Ontology.Index.lookup_type/2`
- [ ] 1.1.5.8 Implement `ElixirCoder.Ontology.Index.persist/2` saving to disk
- [ ] 1.1.5.9 Implement `ElixirCoder.Ontology.Index.load/1` restoring from disk

### 1.1.6 Unit Tests

- [ ] **Task 1.1.6 Complete**

- [ ] Test ontology file parsing loads all triples without errors
- [ ] Test individual extraction returns correct counts by type
- [ ] Test linearization produces valid text format
- [ ] Test index lookup returns correct individuals
- [ ] Test index persistence survives process restart
- [ ] Test multi-hop traversal includes related individuals

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

## 1.5 Ontology Annotation

- [ ] **Section 1.5 Complete**

This section annotates extracted code with ontology information, creating the linearized triple representations that will be used during training. For each function, module, and type, we lookup corresponding ontology individuals and generate text annotations.

### 1.5.1 AST-Based Entity Extraction

- [ ] **Task 1.5.1 Complete**

Implement extraction of code entities from parsed AST for ontology lookup.

- [ ] 1.5.1.1 Implement `ElixirCoder.Annotation.Extractor.extract_modules/1`
- [ ] 1.5.1.2 Implement `ElixirCoder.Annotation.Extractor.extract_functions/1`
- [ ] 1.5.1.3 Implement `ElixirCoder.Annotation.Extractor.extract_types/1`
- [ ] 1.5.1.4 Implement `ElixirCoder.Annotation.Extractor.extract_behaviours/1`
- [ ] 1.5.1.5 Implement `ElixirCoder.Annotation.Extractor.extract_calls/1` for usage relationships
- [ ] 1.5.1.6 Return structured entity list with line numbers and metadata

### 1.5.2 Ontology Lookup

- [ ] **Task 1.5.2 Complete**

Implement lookup of ontology individuals for extracted code entities.

- [ ] 1.5.2.1 Implement `ElixirCoder.Annotation.Lookup.find_module/2`
- [ ] 1.5.2.2 Implement `ElixirCoder.Annotation.Lookup.find_function/4`
- [ ] 1.5.2.3 Implement `ElixirCoder.Annotation.Lookup.find_behaviour/2`
- [ ] 1.5.2.4 Implement `ElixirCoder.Annotation.Lookup.find_type/2`
- [ ] 1.5.2.5 Handle missing individuals gracefully (return `nil` or default)
- [ ] 1.5.2.6 Implement fuzzy matching for similar entity names

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
- [ ] Test ontology lookup returns correct individuals
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

## 1.8 Dataset Assembly

- [ ] **Section 1.8 Complete**

This section assembles the final training dataset from all annotated sources, creating balanced splits for training, validation, and testing.

### 1.8.1 Dataset Schema Definition

- [ ] **Task 1.8.1 Complete**

Define the schema for training examples encompassing all task types.

- [ ] 1.8.1.1 Define `ElixirCoder.Dataset.Schema` struct with fields:
- [ ] 1.8.1.2 Fields: id, code, test, ontology_annotation, credo_issues, sobelow_findings
- [ ] 1.8.1.3 Add metadata: source, language, license, timestamp
- [ ] 1.8.1.4 Define JSON encoding/decoding

### 1.8.2 Train/Val/Test Split

- [ ] **Task 1.8.2 Complete**

Implement dataset splitting ensuring no package appears across splits.

- [ ] 1.8.2.1 Implement `ElixirCoder.Dataset.Split.by_package/3` (80/10/10)
- [ ] 1.8.2.2 Ensure all files from same package go to same split
- [ ] 1.8.2.3 Implement stratified sampling for balanced representation
- [ ] 1.8.2.4 Create `data/processed/train.jsonl`, `val.jsonl`, `test.jsonl`

### 1.8.3 Statistics and Analysis

- [ ] **Task 1.8.3 Complete**

Compute and report dataset statistics for validation.

- [ ] 1.8.3.1 Implement `ElixirCoder.Dataset.Stats.compute/1`
- [ ] 1.8.3.2 Report: total examples, tokens, functions, modules
- [ ] 1.8.3.3 Report: Credo violation distribution
- [ ] 1.8.3.4 Report: Sobelow finding distribution
- [ ] 1.8.3.5 Report: Ontology coverage percentage
- [ ] 1.8.3.6 Create `data/processed/stats.json`

### 1.8.4 Unit Tests

- [ ] **Task 1.8.4 Complete**

- [ ] Test dataset schema encodes/decodes correctly
- [ ] Test split has no package leakage
- [ ] Test statistics are accurate
- [ ] Test all splits have balanced distributions

---

## Success Criteria

1. **Corpus Size**: 50GB+ of processed Elixir source code
2. **Code-Test Pairs**: 10,000+ annotated pairs
3. **Ontology Coverage**: 60%+ of functions mapped to ontology individuals
4. **Quality Labels**: Credo annotations for all source files
5. **Security Labels**: Sobelow annotations for all web code
6. **Dataset Balance**: Train/val/test splits with no package leakage

## Provides Foundation

This phase establishes the data for:
- **Phase 2**: Source code trains custom tokenizer
- **Phase 3**: Annotated examples inform architecture design
- **Phase 4**: Dataset feeds training pipeline
- **Phase 5**: Labels enable multi-task training
