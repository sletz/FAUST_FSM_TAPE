# FAUST Nested With-Block Bug

## Issue

When `rdtable` lookups are placed inside deeply nested `with { }` blocks (library-style structure), the harmonic behavior breaks:
- Noise floor becomes flat/straight line instead of natural noise
- Aliasing artifacts appear
- Harmonic imprint is incorrect

## Test Cases

Three minimal test files to reproduce:

| File | Structure | Expected Result |
|------|-----------|-----------------|
| `test_flat.dsp` | Flat top-level | WORKING (reference) |
| `test_nested_with.dsp` | Nested `with { }` | expected BROKEN (Works when single model!) |
| `test_nested_env.dsp` | Nested `environment { }` | To test |

### How to test

```bash
# Compile each test
faust2jaqt test_flat.dsp
faust2jaqt test_nested_with.dsp
faust2jaqt test_nested_env.dsp

# Or build as plugins and analyze in Plugin Doctor
```

Compare harmonic analysis in Plugin Doctor or similar tool. The broken version shows:
- Flat noise floor (straight line) instead of natural noise
- Aliasing artifacts
- Incorrect harmonic imprint

## Working Structure (flat)

```faust
// Top-level definitions
ja_loop_k28(...) = ... with { ... };
ja_hysteresis(...) = ... with { ... };
process = ...;
```

## Broken Structure (nested with)

```faust
tape_channel(...) = ... with {
  // Everything nested inside
  ja_loop_k28(...) = ... with { ... };
  ja_hysteresis(...) = ... with { ... };
  ...
};
process = tape_channel_ui;
```

## Files

- `test_flat.dsp` - Flat structure (WORKING reference)
- `test_nested_with.dsp` - Nested with blocks (BROKEN)
- `test_nested_env.dsp` - Nested environment blocks (testing Stéphane's suggestion)
- `ja_streaming_bias_proto_lib.dsp` - Original broken library-style prototype
- `ja_streaming_bias_proto_old.dsp` - Old version before GRAME reorg

## Date

2025-11-29

## To Report

Reported to GRAME/Stéphane Letz - awaiting feedback on `environment { }` vs `with { }` behavior.
