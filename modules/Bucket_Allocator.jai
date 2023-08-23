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
			#if USE_UNMAPPING_ALLOCATOR {
				assert(old_memory.* == 0xCC, "Didn't wipe on free correctly!");
			}
			return null;

		case .STARTUP;	#through;
		case .SHUTDOWN;
			return null;

		case .THREAD_START;	#through;
		case .THREAD_STOP;
			assert(false, "Threading not supported [yet?].");

		case .CREATE_HEAP;	#through;
		case .DESTROY_HEAP;
			assert(false, "Heaps not supported.");

		case .IS_THIS_YOURS;
			return cast(*void) cast(s64) (findBucket(bucketAllocator, old_memory) > 0);

		case .CAPS;
			if old_memory {
				(cast(*string)old_memory).* = CAPS_VERSION_STRING;
			}
			return cast(*void)(Allocator_Caps.FREE|.ACTUALLY_RESIZE|.IS_THIS_YOURS);
	}

	assert(false, "unreachable");
	return null;
}

#if RECORD_STATS {
	printStats :: (using bucketAllocator: BucketAllocator, compact := false) {
		using Basic :: #import "Basic";
		print("BucketAllocator @%\n", formatInt(*bucketAllocator, base=16));
		if (compact) {
			for 0..SIZES_CONFIG.count - 1 {
				print("  %: %/% = %4%%\n", it + 4, stats[it].highWaterMark, SIZES_CONFIG[it], (10000 * stats[it].highWaterMark / SIZES_CONFIG[it]) / 100.0);
			}
		} else {
			for 0..SIZES_CONFIG.count - 1 {
				print("  Size: %\n", it + 4);
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
	initBucket(*size4Bucket);
	initBucket(*size5Bucket);
	initBucket(*size6Bucket);
	initBucket(*size7Bucket);
	initBucket(*size8Bucket);
	initBucket(*size9Bucket);
	initBucket(*size10Bucket);
	initBucket(*size11Bucket);
	initBucket(*size12Bucket);
}

deInit :: (using bucketAllocator: *BucketAllocator) {
	free(bucketAllocator, allocator);
}

#scope_file

CAPS_VERSION_STRING :: "Bucket_Allocator v0.8";

initBucket :: (bucket: *BucketSet($S, $L)) {
	for < L - 1..0 {
		ref := bucket.refs[it];
		ref.item = xx *bucket.items[it];
		ref.next = bucket.freeList;
		bucket.freeList = *ref;
	}
	bucket.usedList = null;
}

#if HONOUR_REALLOC_SHRINK {
	reallocShouldNotMove :: (size: int, oldSize: int) -> bool {
		return oldSize == size;
	}
} else {
	reallocShouldNotMove :: (size: int, oldSize: int) -> bool {
		return oldSize >= size;
	}
}

allocate :: (using bucketAllocator: *BucketAllocator, mode: Allocator_Mode, requestedSize: s64, oldSize: s64, oldMemory: *void) -> *void {
	size := calculateSize(requestedSize);
	ref: *BucketItemRef;

	if mode == .RESIZE {
		oldSize, oldRef := findBucket(bucketAllocator, oldMemory, requestedSize);
		assert(oldSize > 0, "Not our memory!");
		#if RECORD_STATS {
			index :: size - 4;
			stats[index].reallocateReqiests += 1;
		}

		if reallocShouldNotMove(size, oldSize) {
			return oldMemory;
		}


		#if RECORD_STATS {
			if oldSize < size {
				stats[index].reallocateGrowsNeeded += 1;
			} else {
				stats[index].reallocateShrinksNeeded += 1;
			}
		}
		ref = allocateNew(bucketAllocator, size);

		memcpy(ref.item, oldRef.item, 1<<min(size, oldSize));	// @Speed: if the requested size lots smaller than bucket's size we are copying more than we need.  Not sure we care.
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

allocateNew :: inline (using bucketAllocator: *BucketAllocator, size: int) -> *BucketItemRef {
	if size == {
		// :MetaSizing Can we be smarter about this with #insert?
		case 4;
			return allocateNew(bucketAllocator, *size4Bucket);
		case 5;
			return allocateNew(bucketAllocator, *size5Bucket);
		case 6;
			return allocateNew(bucketAllocator, *size6Bucket);
		case 7;
			return allocateNew(bucketAllocator, *size7Bucket);
		case 8;
			return allocateNew(bucketAllocator, *size8Bucket);
		case 9;
			return allocateNew(bucketAllocator, *size9Bucket);
		case 10;
			return allocateNew(bucketAllocator, *size10Bucket);
		case 11;
			return allocateNew(bucketAllocator, *size11Bucket);
		case 12;
			return allocateNew(bucketAllocator, *size12Bucket);
		case;
			assert(false, "Bad size %!", size);
			return null;
	}
}

allocateNew :: (using bucketAllocator: *BucketAllocator, bucket: *BucketSet($S, $L)) -> *BucketItemRef {
	#if RECORD_STATS {
		index :: S - 4;
		stats[index].allocated += 1;
		mark := stats[index].allocated - stats[index].freed;
		if mark > stats[index].highWaterMark {
			stats[index].highWaterMark = mark;
		}
	}

	ref := bucket.freeList;
	if !ref {
		return null;
	}


	ref.next = bucket.usedList;
	bucket.usedList = ref;

	return ref;
}

free :: (using bucketAllocator: *BucketAllocator, oldMemory: *void) {
	#if RECORD_STATS {
		stats[size].freed += 1;
	}
	oldSize := findBucket(bucketAllocator, oldMemory, -1);
	assert(oldSize > 0, "Not our memory!");
}

findBucket :: (using bucketAllocator: *BucketAllocator, memory: *void, newSize: int = 0) -> int, *BucketItemRef {
	testBucket :: (memory: *void, bucket: *BucketSet($S, $L)) #expand {
		itemSize :: 1 << S;
		offset : s64 = cast(s64) *bucket.items[0] - cast(s64) memory;
		inside := offset >= 0 && offset < itemSize * SIZES_CONFIG[S - 4];
		if (inside) {
			ref: *BucketItemRef;
			assert(offset % itemSize == 0, "Don't free the middle of an item!");
			if (`newSize < 0 || !reallocShouldNotMove(S, `newSize)) {
				ref = unallocateRef(bucket, memory);
			}

			`return S, ref;
		}
	}

	// :MetaSizing Can we be smarter about this with #insert?
	testBucket(memory, *size4Bucket);
	testBucket(memory, *size5Bucket);
	testBucket(memory, *size6Bucket);
	testBucket(memory, *size7Bucket);
	testBucket(memory, *size8Bucket);
	testBucket(memory, *size9Bucket);
	testBucket(memory, *size10Bucket);
	testBucket(memory, *size11Bucket);
	testBucket(memory, *size12Bucket);

	return 0, null;
}

unallocateRef :: (using bucket: *BucketSet($S, $L), memory: *void) -> *BucketItemRef {
	// @Speed: finding the allocated bucket is O(n)...
	prev: *BucketItemRef;
	ref := usedList;

	assert(ref != null, "Nothing allocated here!");
	while (ref && memory != xx ref.item) {
		prev = ref;
		ref = ref.next;
	}
	assert(ref != null, "Didn't find the ref!");

	if prev {
		prev.next = ref.next;
	} else {
		usedList = ref.next;
	}

	ref.next = freeList;
	freeList = ref;

	#if USE_UNMAPPING_ALLOCATOR {
		memset(ref.item, 0xCC, 1<<S);
	}

	return ref;
}

#scope_export

BucketAllocator :: struct {
	allocator: Allocator;

	// :MetaSizing Can we be smarter about this with #insert?
	size4Bucket: BucketSet(size = 4, length = SIZES_CONFIG[0]);
	size5Bucket: BucketSet(size = 5, length = SIZES_CONFIG[1]);
	size6Bucket: BucketSet(size = 6, length = SIZES_CONFIG[2]);
	size7Bucket: BucketSet(size = 7, length = SIZES_CONFIG[3]);
	size8Bucket: BucketSet(size = 8, length = SIZES_CONFIG[4]);
	size9Bucket: BucketSet(size = 9, length = SIZES_CONFIG[5]);
	size10Bucket: BucketSet(size = 10, length = SIZES_CONFIG[6]);
	size11Bucket: BucketSet(size = 11, length = SIZES_CONFIG[7]);
	size12Bucket: BucketSet(size = 12, length = SIZES_CONFIG[8]);
	#if RECORD_STATS {
		stats: [9] BucketStats;
	}
}

BucketSet :: struct(size: int, length: int) {
	items: [length] [1 << size] u8;
	refs: [length] BucketItemRef;
	freeList: *BucketItemRef;
	usedList: *BucketItemRef;
}

BucketItemRef :: struct {
	item: *u8;
	next: *BucketItemRef;
}

BucketStats :: struct {
	allocated: int;
	reallocateReqiests: int;
	reallocateGrowsNeeded: int;
	reallocateShrinksNeeded: int;
	freed: int;
	highWaterMark: int;
}
