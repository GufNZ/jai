# jai
Jai experiments.

## Bucket Allocator
Inspired by something Jon mentioned on a compiler stream about an allocator that can handle any type, but is not as complex as a full malloc implementation.

This allocator has buckets of fixed-sized (power of 2) chunks of memory, and allocates from the smallest one to fit the requested size.
The sizes available and the number of each is controled with the SIZES_CONFIG param - see below.
Everything is dynamically created off this config so there's no waste.

It does not support create_/destroy_heap() nor is it yet tested for multithreading.

It supports allocating, freeing, and also resizing:
- If the new size still fits in the same sized bucket, nothing moves.
- If the new size needs a larger bucket, a new allocation is made and the data copied into it.
- If the new size fits in a smaller bucket, either nothing happens or a new allocation is made and the smaller size worth of data is copied, depending on HONOUR_REALLOC_SHRINK - see below.

It also optionally records statistics that can then be printed, aiding in tuning the SIZES_CONFIG to your code's runtime needs, if you want to configure it as lean as needed for example.

Allocations are managed via a free-list and used-list, which means freeing has an O(n) component at the moment.  Might consider bit arrays if this becomes a performance issue.

Note that allignment is only ensured if the initial allocation of the BucketArray instance is also aligned.

### Module Parameters:
Currently none, tho I'm considering moving SIZES_CONFIG to be one instead of a Program Parameter.
This would allow there to be multiple instances with different configs, rather than the current paradigm that expects there to only ever be one \[configuration].

### Program Parameters:
- `SIZES_CONFIG`:
	This int array defines how many sizes of bucket there will be (by its length), as well as how many of each size there will be (by the values).
	The smallest bucket is for 16byte allocations, so the first entry in the array controls how many of those will exist.  The next entry, if it is present, is for 32byte allocations, etc.
	If an entry is `0` then that size will be excluded and allocations that would want that size will fail.
	As many buckets as non-zero entries will be created.
	Default is `.[65536, 32768, 16384, 8192, 4096, 2048, 1024, 512, 256]` which will allocate 1MiB for each size from 16bytes to 4096bytes.

- `USE_UNMAPPING_ALLOCATOR`:
	Like other allocators, stomps freed memory with 0xCC if true, to aid in memory debugging.
	Defaults to `false`.

- `HONOUR_REALLOC_SHRINK`:
	If `false`, a `realloc()` that asks for less memory won't actually do anything, leaving the allocation where it is.
	If `true`, a shrink will cause a reallocation (if it would cause a difference in bucket size).
	Note that `realloc()`s that don't alter the bucket size the allocation is in, either grows or shrinks, will always be NOPs anyway, regardless of this parameter.

- `RECORD_STATS`:
	If `true`, we allocate a bit more RAM to hold usage stats and update them as things are allocated/reallocated/freed.
	It also defines `print_stats(*BucketAllocator, compact=false)` that can then print the stats.
	This is useful if you want to initialise to a configuration that allocates no more than it needs to for example.
	Defaults to `false`.

- `ALLOW_OVERFLOW`:
	If `true`, an attempt to allocate what would go into a certain sized bucket is allowed to overflow to the next size up if there are no entries left.
	This continues until a successful allocation or we run out of sizes to try.
	Defaults to `true`.

### Example:
The usual pattern for use would be something like:

	#import "Bucket_Allocator"()(SIZES_CONFIG = int.[10,10,10,10]);

	...

	newContext := context;
	newContext.allocator = make_bucket_allocator();
	push_context newContext {
		...do stuff using the new allocator, remembering that everything including print will then use it...
	}

Or alternatively, using the push_allocator macro:

	...
	push_allocator(make_bucket_allocator());
	...do stuff using the new allocator, till the end of the current scope...

### API:
- `make_bucket_allocator() -> Allocator`
	Allocates a `BucketAllocator` (via `New()`) and returns an Allocator struct configured to use it.

- `free_bucket_allocator(Allocator)`
	Frees the `BucketAllocator` configured in the supplied Allocator struct.
	Not expected to be needed much but is here for completeness.

- `init(*BucketAllocator)`
	For in case you want to create the `BucketAllocator` yourself but still need to initialise it.
	Note that this sets up the initial free-lists so is necessary to call before you can use the `BucketAllocator` instance; `make_bucket_allocator()` calls this for you.

- `de_init(*BucketAllocator)`
	Frees the supplied allocator by calling free() on it.
	Again, not expected to be needed much but is here for completeness.

`#if RECORD_STATS {`
- `print_stats(*BucketAllocator, compact=false)`
	Prints either detailed or compact stats about the supplied `BucketAllocator`.
	Compact stats just print the used/total counts and a percentage full per bucket size.

`}`

- `bucket_allocator_proc(Allocator_Mode, s64, s64, *void, *void) -> *void`
	The Allocator_Proc that drives the `BucketAllocator`.
	Not expected to be called directly, but rather via calls to `alloc(s64[, *Allocator])`, `realloc(*void, s64, s64[, *Allocator])`, `free(*void[, *Allocator])`, and `get_capabilities(*Allocator)`.
