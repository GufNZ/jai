# jai
Jai experiments.

## AST Utils
A set of tools for walking the compile-time AST to make metaprogramming easier.

Includes filtering and transformation utils as well as helpers like `hasNote` and `filenameIs` to allow for concise but powerful code modifications/checks.

Details: [AST Utils module](modules/AST_Utils/README.md).

## Bucket Allocator
Inspired by something Jon mentioned on a compiler stream about an allocator that can handle any type, but is not as complex as a full malloc implementation.

This allocator has buckets of fixed-sized (power of 2) chunks of memory, and allocates from the smallest one to fit the requested size.
The sizes available and the number of each is controled with the SIZES_CONFIG param - see below.
Everything is dynamically created off this config so there's no waste.

Details: [Bucket Allocator module](modules/Bucket_Allocator/README.md).

## Coming soon: Units

Currently WIP and also stuck behind a compiler bug.

Details: [Units module](modules/Units/README.md).
