#import "Basic";
/*
//TODO: docs
//TEST: this

allocator with buckets
bucket sizes are 2^x, for x:[4..12]
alloc:
	bucket size to use = min(4,log2(size))

	freeList/usedList

free:
	freeList/usedList

realloc:
	alloc, copy, freeOld.

//LATER: logging?, //MAYBE: extra storage when full (iff RECORD_STATS?)?

*/

// Defaults are 1MiB each size.  Not sure if that makes sense yet.
//QUESTION: should SIZES_CONFIG be a module or a program param?
#module_parameters ()(SIZES_CONFIG := int.[65536, 32768, 16384, 8192, 4096, 2048, 1024, 512, 256], USE_UNMAPPING_ALLOCATOR := false, HONOUR_REALLOC_SHRINK := false, RECORD_STATS := false);

bucket_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
	bucketAllocator := cast(*BucketAllocator)allocator_data;

	if #complete mode == {
		case .ALLOCATE; #through;
		case .RESIZE;
			return allocate(bucketAllocator, mode, requested_size, old_size, old_memory);
		case .FREE;
			free(bucketAllocator, old_memory);
			return null;

		case .STARTUP;	#through;
		case .SHUTDOWN;
			return null;

		case .THREAD_START;	#through;
		case .THREAD_STOP;
			assert(false, "Threading not supported yet.");

		case .CREATE_HEAP;	#through;
		case .DESTROY_HEAP;
			assert(false, "Heaps not supported.");

		case .IS_THIS_YOURS;
			return cast(*void) cast(s64) (findBucket(bucketAllocator, old_memory) > 0);

		case .CAPS;
			if old_memory {
				cast(*string)old_memory.* = CAPS_VERSION_STRING;
			}
			return cast(*void)(Allocator_Caps.FREE|.ACTUALLY_RESIZE|.IS_THIS_YOURS);
	}

	assert(false, "unreachable");
}

#if RECORD_STATS {
	printStats :: (using bucketAllocator: BucketAllocator, compact := false) {
		using Basic :: #import "Basic";
		print("BucketAllocator @%\n", formatInt(*bucketAllocator, base=16));
		if (compact) {
			// :MetaSizing Can we be smarter about this with #insert?
			for 4..12 {
				print("  %: %/% = %4%%\n", it, stats[it].highWaterMark, SIZES_CONFIG[it], (10000 * stats[it].highWaterMark / SIZES_CONFIG[it]) / 100.0);
			}
		} else {
			// :MetaSizing Can we be smarter about this with #insert?
			for 4..12 {
				print("  Size: %\n", it);
				print("    Allocated : %\n", stats[it].allocated);
				print("    Freed     : %\n", stats[it].freed);
				print("    High Water: %\n", stats[it].highWaterMark);
				print("    LIMIT     : %\n", SIZES_CONFIG[it]);
				print("      %%       : %\n", (10000 * stats[it].highWaterMark / SIZES_CONFIG[it]) / 100.0);
				print("    Reallocate:\n");
				print("      Requested: %\n", stats[it].reallocateRequests);
				print("      NOPs     : %\n", stats[it].reallocateRequests - (stats[it].reallocateGrowsNeeded + stats[it].reallocateShrinksNeeded));
				print("      Grows    : %\n", stats[it].reallocateGrowsNeeded);
				#if HONOUR_REALLOC_SHRINK {
					print("      Shrinks  : %\n", stats[it].reallocateShrinksNeeded);
				}
			}
		}
	}
}

makeBucketAllocator :: () -> Allocator {
	ba := New(BucketAllocator);
	init(ba);
	return .{ proc = bucket_allocator_proc, data = xx ba };
}

freeBucketAllocator :: (a: Allocator) {
	assert(a.proc == bucket_allocator_proc && a.data, "Not a BucketAllocator!");
	ba: cast(*BucketAllocator) a.data;
	deInit(ba);
}

init :: (using bucketAllocator: *BucketAllocator) {
	assert(allocator.proc == null, "Already initialised!");
	assert(context.allocator.proc != bucket_allocator_proc, "Can't allocate off ourselves!");
	allocator = context.allocator;

	//QUESTION: :MetaSizing Can we be smarter about this with #insert?
	buckets[0] = xx *size4Bucket;
	buckets[1] = xx *size5Bucket;
	buckets[2] = xx *size6Bucket;
	buckets[3] = xx *size7Bucket;
	buckets[4] = xx *size8Bucket;
	buckets[5] = xx *size9Bucket;
	buckets[6] = xx *size10Bucket;
	buckets[7] = xx *size11Bucket;
	buckets[8] = xx *size12Bucket;

	// :MetaSizing Can we be smarter about this with #insert?
	for 4..12 {
		bucket = cast(*BucketSet(size=it)) buckets[it - 4];
		for < SIZE_CONFIG[it]..0 {
			ref := bucket.refs[it];
			ref.item = *bucket.items[it];
			ref.next = bucket.freeList;
			bucket.freeList = *ref;
		}
		bucket.usedList = null;
	}
}

deInit :: (using bucketAllocator: *BucketAllocator) {
	free(bucketAllocator, allocator);
}

#scope_file

allocate :: (using bucketAllocator: *BucketAllocator, mode: Allocator_Mode, requestedSize: s64, oldSize: s64, oldMemory: *void) -> *void {
	size := calculateSize(requestedSize);
	ref: BucketItemRef;

	if mode == .RESIZE {
		oldSize := findBucket(bucketAllocator, oldMemory);
		assert(oldSize > 0, "Not our memory!");
		#if RECORD_STATS {
			stats[size].reallocateReqiests += 1;
		}

		#if HONOUR_REALLOC_SHRINK {
			if oldSize == size {
				return oldMemory;
			}
		} else {
			if oldSize >= size {
				return oldMemory;
			}
		}


		#if RECORD_STATS {
			if oldSize < size {
				stats[size].reallocateGrowsNeeded += 1;
			} else {
				stats[size].reallocateShrinksNeeded += 1;
			}
		}
		ref = allocateNew(bucketAllocator, size);

		bucket = cast(Bucket(oldSize)) buckets[oldSize];
		oldRef := unallocRef(bucket, oldMemory);
		memcpy(ref.item, oldRef.item, 1<<oldSize);	// @Speed: if the requested size lots smaller than bucket's size we are copying more than we need.  Not sure we care.
	} else {
		ref = allocateNew(bucketAllocator, size);
	}

	return ref.item;
}

calculateSize :: (requestedSize: s64) -> int {
	//TODO: #asm to find the top bit...
	size := 4;
	length := 1<<size;
	while length < requestedSize {
		size += 1;
		length <<= 1;
	}

	return size;
}

allocateNew :: (using bucketAllocator: *BucketAllocator, size: int) -> BucketItemRef(size) {
	// :MetaSizing Can we be smarter about this with #insert?
	assert(size < 12, "Too Big!");

	#if RECORD_STATS {
		stats[size].allocated += 1;
		mark := stats[size].allocated - stats[size].freed;
		if mark > stats[size].highWaterMark {
			stats[size].highWaterMark = mark;
		}
	}

	bucket := cast(Bucket(size)) buckets[size - 4];
	ref := bucket.freeList;
	if !ref {
		return null;
	}


	ref.next = usedList;
	usedList = *ref;

	return ref;
}

free :: (using bucketAllocator: *BucketAllocator, oldMemory: *void) {
	#if RECORD_STATS {
		stats[size].freed += 1;
	}
	oldSize := findBucket(bucketAllocator, oldMemory);
	assert(oldSize > 0, "Not our memory!");
	bucket := cast(Bucket(oldSize)) buckets[oldSize];
	unallocRef(bucket, oldMemory);
}

findBucket :: (using bucketAllocator: *BucketAllocator, memory: *void) -> int {
	testBucket :: ($size: int, memory: *void) -> bool {
		bucket := cast(BucketSet(size)) buckets[it - 4];
		//TEST: this end logic:
		return memory >= *bucket.items[0] && memory < *bucket.items[0] + SIZES_CONFIG[it];
	}

	// :MetaSizing Can we be smarter about this with #insert?
	for 4..12 {
		test := #bake_arguments testBucket(size = it);
		if (test(memory)) {
			return it;
		}
	}


	return 0;
}

unallocRef :: (using bucket: *BucketSet($T), memory: *void) -> *BucketItemRef(T) {
	// @Speed: finding the allocated bucket is O(n)...
	prev: *BucketItemRef(T);
	ref := usedList;

	assert(ref, "Nothing allocated here!");
	while (ref && memory != xx ref.item) {
		prev = ref;
		ref = ref.next;
	}
	assert(ref, "Didn't find the ref!");

	if prev {
		prev.next = ref.next;
	} else {
		usedList = ref.next;
	}

	ref.next = freeList;
	freeList = ref;

	#if USE_UNMAPPING_ALLOCATOR {
		memset(ref.item, 0xCC, 1<<T);
	}

	return ref;
}

#scope_export

BucketAllocator :: struct {
	allocator: Allocator;

	// :MetaSizing Can we be smarter about this with #insert?
	size4Bucket := BucketSet(size = 4, length = SIZES_CONFIG[0]);
	size5Bucket := BucketSet(size = 5, length = SIZES_CONFIG[1]);
	size6Bucket := BucketSet(size = 6, length = SIZES_CONFIG[2]);
	size7Bucket := BucketSet(size = 7, length = SIZES_CONFIG[3]);
	size8Bucket := BucketSet(size = 8, length = SIZES_CONFIG[4]);
	size9Bucket := BucketSet(size = 9, length = SIZES_CONFIG[5]);
	size10Bucket := BucketSet(size = 10, length = SIZES_CONFIG[6]);
	size11Bucket := BucketSet(size = 11, length = SIZES_CONFIG[7]);
	size12Bucket := BucketSet(size = 12, length = SIZES_CONFIG[8]);
	buckets: [9] *BucketSet;
	#if RECORD_STATS {
		stats: [9] BucketStats;
	}
}

BucketSet :: struct(size := 4, length := 256) {
	items := [length] BucketItem(size);
	refs := [length] BucketItemRef(size);
	freeList: *BucketItemRef(size);
	usedList: *BucketItemRef(size);
}

BucketItemRef :: struct(size := 4) {
	item: *BucketItem(size);
	next: *BucketItemRef;
}

//QUESTION: do I need this or can I inline it..?
BucketItem :: struct(size := 4) {
	data := [1 << size] u8;
}

BucketStats :: struct {
	allocated: int;
	reallocateReqiests: int;
	reallocateGrowsNeeded: int;
	reallocateShrinksNeeded: int;
	freed: int;
	highWaterMark: int;
}
