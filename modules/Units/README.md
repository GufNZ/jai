## Units module

A module to define types representing various combinations of SI units, and operators on those values that generate the appropriate result types, such that mismatching the units is a compile-error, but at runtime there is zero cost.

### Overview

The Units module provides compile-time unit type safety with zero runtime overhead.  Unit types are parameterized by:

- **Exponents** (Exp) - dimensional power (e.g., 2 for m²)
- **Ratios** (Num/Denom) - scale factors (e.g., Num=1000 for kilometers)
- **Scale** - multiplicative scaling
- **Offset** - additive offset (for temperature scales like Celsius)
- **DataType** - underlying numeric type (float, float64, int, etc.)

### Core Conversion Functions

#### `unboxSI(x: $T/SIQuantity) -> T.DataType`

Extracts the canonical SI value from a unit quantity. The result is always in base SI units.

- **Meters(100)** -> 100.0 (SI meters)
- **Kilometers(2)** -> 2000.0 (SI meters)
- **Celsius(20)** -> 293.15 (SI Kelvin)

Use this to convert any unit quantity to its canonical SI representation.

#### `boxSI(target: $T/Type, value: T.DataType) -> T`

Wraps a canonical SI value back into the target unit frame. The function validates at compile-time that `T` is an SIQuantity type via `#modify`.

- `boxSI(Meters(float), 100.0)` -> **Meters(100)**
- `boxSI(Kilometers(float), 2000.0)` -> **Kilometers(2)**
- `boxSI(Celsius(float), 293.15)` -> **Celsius(20)**

#### Round-trip Conversion

Combining `unboxSI` and `boxSI` enables arbitrary unit conversions:

```jai
// Convert 100 meters to kilometers
m := Meters(float).{100};
km := boxSI(Kilometers(float), unboxSI(m));  // Kilometers(0.1)
```

### Operator Behavior

#### Same-Type Arithmetic (Zero Overhead)

Operations between identical types use direct arithmetic with no conversion overhead:

```jai
a := Meters(float).{100};
b := Meters(float).{50};
result := a + b;  // Direct: result.amount = 100 + 50
```

#### Mixed-Ratio Arithmetic (Compile-Time Constants)

Addition/subtraction of different ratio units bakes conversion constants at compile-time:

```jai
m := Meters(float).{100};
km := Kilometers(float).{2};
result := m + km;  // Type: Meters; amount = 100 + (2 * 1000) = 2100
```

The conversion factor (1000 for kilometers to meters) is baked into the generated code as a constant.

#### Multiplication/Division (LHS Frame Preservation)

Mixed-ratio multiply/divide preserves the left-hand side unit frame:

```jai
m_per_s := MetersPerSecond(float).{2};
km_per_s := KilometersPerSecond(float).{3};
result := m_per_s * km_per_s;  // Type: (m/s)², amount = 2 * (3 * 1000) = 6000
```

#### Offset Handling (Conservative Policy)

Quantities with offsets (e.g., Celsius) are restricted in mixed operations:

- **Addition/subtraction** - Allowed, with offset conversion applied
- **Multiplication/division** - **Blocked** (semantically invalid, e.g., 20°C × 21°C has no meaning)

```jai
c := Celsius(float).{20};
k := Kelvin(float).{293.15};
sum := c + k;  // OK: converts and adds
product := c * k;  // Compile error: offsets not allowed in multiply
```

### Type Checking Infrastructure

#### Predicate Functions

Low-level predicates for unit compatibility:

- `ratiosEqual(a, b)` - check if Num/Denom match
- `exponentsEqual(a, b)` - check if exponents match
- `scalesEqual(a, b)` - check if scales match
- `offsetsEqual(a, b)` - check if offsets match
- `hasAnyOffset(p)` - check if any dimension has non-zero offset

Higher-level predicates:

- `isDimensionallyEqual(a, b)` - same DataType and exponents
- `isStrictlyIdenticalUnits(a, b)` - identical in all parameters
- `isAddSubConvertible(a, b)` - can be added/subtracted with conversion
- `isSIQuantityType(T)` - runtime check that type T is an SIQuantity

#### Polymorph Detection (`isSIQuantityType`)

The function checks both:
1. **Polymorph source** - if it's a specialization of the SIQuantity generic struct.
2. **Direct struct name** - if the type is literally named "SIQuantity".

This handles both concrete instances (e.g., `Meters(float64)` created via `#insert SI(...)`) and direct parameterized references.

### Consistency Notes

**Naming conventions:**
- `<field>Equal` - single-field equality checks (low-level)
- `is<Semantic>` - high-level composite queries (dimensional equality, convertibility)
- `has<Property>` - state/presence checks (offset, ratios)

**Parameter ordering:**
- Conversion functions take target type first to enable type inference
- Predicates consistently use `(a, b)` ordering
- Operators preserve left-to-right argument order

### Implementation Architecture

All arithmetic operators are implemented via:

1. **Fast path** (exact same-type) - Direct arithmetic, `#modify` guard returns `false` to select this overload
2. **Slow path** (mixed-ratio) - `#modify` computes conversion constants and bakes them into operator specialization
3. **Rejection path** (invalid) - `#modify` returns `false` with diagnostic message when operation is semantic invalid (e.g., offset in multiply)

The `#modify` guards ensure:
- No runtime cost for same-type operations
- One-time constant computation per polymorphic specialization
- Clear error messages when operations are rejected
