# Get-ChildItem: PS1 to durable CLR command

Status: experiment only. Nothing in this directory is an admitted application command yet.

## Goal

Prove this bounded path without generated C#, Roslyn, a project file, or the Microsoft management-command assembly:

```text
Get-ChildItem.ps1
  -> SMA parser and AST
  -> admitted command lowering
  -> persisted ECMA-335 assembly
  -> load through SMA/CoreCLR
  -> RyuJIT at execution
  -> filesystem objects equivalent to the interpreted PS1 source
```

"AOT at home" means that PS1 is parsed and lowered to durable CLR IL during `Build-AndroidSMA.ps1`; it does not mean NativeAOT. RyuJIT still performs the target-specific native compilation when the emitted method executes.

SMA's ordinary compiled-script path may produce executable dynamic methods, but those methods are not automatically saveable assemblies. This experiment must implement the small admitted AST-to-IL bridge honestly.

## Mirrored project address

Keep the conceptual addresses aligned across AndroidSMA and DirectPortSMA:

```text
Experiments/SMA/RyuJIT/Get-ChildItem/   # unproven source, lowering, fixtures, receipts
src/Commands/Get-ChildItem/             # validated canonical command only
build/commands/                          # generated assembly and transient build evidence
```

Preserve each repository's established casing (`src` here, `Src` in DirectPortSMA). The hierarchy is a practical mirror, not a demand that platform-specific contents remain identical.

Do not place a command in `src/Commands` merely because it parses, emits, or runs on Windows. Promotion requires the gates below.

## First semantic contract

The first command is deliberately smaller than Microsoft's provider-backed `Get-ChildItem`:

- filesystem only;
- one explicit literal directory path;
- direct children only;
- return real `System.IO.FileSystemInfo` objects;
- deterministic ordinal ordering by full path;
- preserve file versus directory identity and ordinary CLR metadata;
- fail explicitly for a missing or non-directory path.

Not admitted in the first proof:

- registry, certificate, variable, function, or other PowerShell providers;
- wildcard path expansion;
- recursion;
- alternate data streams;
- remoting;
- transactions;
- provider-specific dynamic parameters;
- imitation of undocumented Microsoft command behavior.

Add features only when an application need or a new conformance case makes the requirement concrete.

## Experiment files

The experiment should eventually contain:

```text
Get-ChildItem.ps1             # canonical semantic source while experimental
Build-GetChildItem.ps1       # PS1 AST admission and persisted-IL emission
Test-GetChildItem.ps1        # interpreted/emitted conformance
IMPLEMENTATION-PLAN.md       # this file
fixtures/                    # generated test tree description, not checked-in machine state
receipts/                    # concise text receipts from deliberate runs
```

Do not add TS. The interpreted PS1 source is already the semantic twin and stronger language oracle.

Do not embed the PS1 program as a string in the emitted assembly. The build reads the `.ps1` source as source, parses it, admits its AST, and emits the corresponding method body.

## Implementation stages

### 1. Freeze the interpreted behavior

Write the smallest readable `Get-ChildItem.ps1` using typed CLR filesystem calls. Run it against a temporary tree containing:

- files and directories;
- empty files;
- spaces and Unicode names;
- an empty directory;
- a missing-path case.

Record ordered output objects by type, full path, name, length where applicable, and attributes. Compare error category and target; do not make localized message text part of the contract.

### 2. Admit the AST

Parse with `System.Management.Automation.Language.Parser.ParseFile`. Reject all parser errors before emission.

The first lowerer admits only the AST shapes actually present in the frozen source. Each admitted node must map to a named semantic operation. Unsupported syntax terminates with:

```text
NO ADMITTED LOWERING
```

Do not silently fall back to interpretation during an emitted-path test. Do not use text replacement as a substitute for AST inspection.

### 3. Emit durable IL

Use `System.Reflection.Emit.PersistedAssemblyBuilder`, which is present in the current PowerShell 7.7 / .NET 11 build environment.

Emit a small public filesystem-command type and method with typed parameters and return values. The first method may expose the filesystem operation directly; command registration is a separate seam and must not obscure lowering correctness.

Emit against the Android target reference set rather than accidentally binding the artifact to desktop-only .NET 11 implementation assemblies. Expected references must be enumerated and checked after emission. The artifact must not reference `Microsoft.PowerShell.Commands.Management`.

Write the generated assembly only under `build/commands/`. Source directories never contain generated binaries.

### 4. Inspect before loading

Use `PEReader`/`MetadataReader` or equivalent CLR metadata APIs to verify:

- valid managed PE and metadata;
- expected assembly and type names;
- expected method signature;
- expected assembly references only;
- no generated C# provenance;
- source SHA-256 embedded as metadata or an adjacent receipt;
- deterministic output for identical source, target references, and build inputs, or an explicit account of nondeterministic fields.

### 5. Windows conformance

Load the artifact into a collectible `AssemblyLoadContext` and invoke it against the same temporary tree as the interpreted source.

Compare, in order:

- object count;
- concrete CLR types;
- full paths and names;
- file/directory identity;
- lengths and attributes where defined;
- missing-path failure classification.

The Microsoft `Get-ChildItem` cmdlet is an outside reference only for the explicitly supported overlap. It is not the implementation donor and its full provider semantics are not a requirement.

### 6. Android conformance

Stage the emitted artifact and canonical source through the existing AndroidSMA test path. Create an isolated fixture below app-private storage; do not inspect or mutate unrelated application files.

Run interpreted and emitted paths in the SMA-hosted process and compare the same observations used on Windows. Record:

- device and ABI;
- SMA, CoreCLR, and runtime versions;
- `RuntimeFeature.IsDynamicCodeSupported` and `IsDynamicCodeCompiled`;
- source and assembly hashes;
- load result;
- first and warmed invocation results;
- complete conformance result;
- cleanup result.

Do not call the result RyuJIT-native merely because an assembly loaded. Record the strongest execution evidence actually observed.

### 7. Admit the command surface

Only after both conformance lanes pass, determine the smallest honest SMA command-registration seam. Keep registration separate from filesystem semantics so a host detail cannot masquerade as compiler correctness.

Promote the validated canonical source to:

```text
src/Commands/Get-ChildItem/Get-ChildItem.ps1
```

Teach `Build-AndroidSMA.ps1` to lower that validated source into `build/commands/` and package the resulting assembly. The source remains authoritative; the assembly is reproducible dogfood.

Do not extract a general command compiler during this first proof. When a second materially different command succeeds, promote only the lowering operations proven common to both.

## Acceptance gates

The experiment passes only when:

1. the canonical PS1 parses without error;
2. every accepted AST node has an explicit lowering;
3. identical build inputs produce an inspectable durable managed assembly;
4. the assembly has no Microsoft management-command dependency;
5. interpreted and emitted paths return equivalent real filesystem objects on Windows;
6. interpreted and emitted paths return equivalent real filesystem objects in Android app-private storage;
7. failure behavior is explicit and compared;
8. no emitted-path test silently interprets the source;
9. build, load, execution, comparison, and cleanup produce a concise receipt;
10. the artifact can be rebuilt from the canonical PS1 and admitted build machinery alone.

Until all ten gates pass, this remains an experiment and nothing is copied into `src/Commands`.

## Relationship to the larger command population

This proof does not establish that every PowerShell script can be persisted as IL. It establishes one vertically complete command and teaches us which SMA source shapes lower cleanly.

Future commands are admitted need-first. Each one either reuses proven lowering operations, adds one experimentally justified lowering, or remains interpreted when durability provides no concrete benefit.
