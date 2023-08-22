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

//LATER: stats, logging?, //MAYBE: extra storage when full (iff RECORD_STATS?)?

*/

// Defaults are 1MiB each size.  Not sure if that makes sense yet.
//TODO: Implement RECORD_STATS so users can better know how to configure this...
#module_parameters ()(SIZES_CONFIG = int.[65536, 32768, 16384, 8192, 4096, 2048, 1024, 512, 256], USE_UNMAPPING_ALLOCATOR := false, RECORD_STATS := false);

bucket_allocator_proc :: (mode: Allocator_Mode, requested_size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
	bucketAllocator := cast(*BucketAllocator)allocator_data;
	if #complete mode == {
		case .ALLOCATE; #through
		case .RESIZE;
			return allocate(bucketAllocator, mode, requested_size, old_size, old_memory);
		case .FREE;
			free(bucketAllocator, old_memory);
			return null;

		case .STARTUP;
			init(bucketAllocator);
			return null;
		case .SHUTDOWN;
			deInit(bucketAllocator);
			return null;

		case .THREAD_START;
			assert(false, "Threading not supported yet.");
		case .THREAD_STOP;
			assert(false, "Threading not supported yet.");

		case .CREATE_HEAP;
			assert(false, "Heaps not supported.");
		case .DESTROY_HEAP;
			assert(false, "Heaps not supported.");

		case .IS_THIS_YOURS;
			return cast(*void) cast(s64) (findBucket(bucketAllocator, old_memory) > 0);

		case .CAPS;
			if old_memory { <<cast(*string)old_memory = CAPS_VERSION_STRING; }
			return cast(*void)(Allocator_Caps.FREE|.IS_THIS_YOURS);
	}

	assert(false, "unreachable");
}

#scope_file

init(using bucketAllocator: *BucketAllocator) {
	assert(!allocator, "Already initialised!");
	assert(context.allocator.proc != bucket_allocator_proc)
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

deInit(using bucketAllocator: *BucketAllocator) {
	Basic :: #import "Basic";
	Basic.free(bucketAllocator, allocator);
}

allocate(using bucketAllocator: *BucketAllocator, mode: Allocator_Mode, requestedSize: s64, oldSize: s64, oldMemory: *void) -> *void {
	//TODO: #asm to find the top bit...
	size := 4;
	length := 1<<size;
	while length < requestedSize {
		size += 1;
		length <<= 1;
	}

	// :MetaSizing Can we be smarter about this with #insert?
	assert(size < 12, "Too Big!");

	bucket := cast(Bucket(size)) buckets[size - 4];
	ref := bucket.freeList;
	if !ref  return null;

	ref.next = usedList;
	usedList = *ref;

	if (mode == .RESIZE) {
		oldSize := findBucket(bucketAllocator, oldMemory);
		assert(oldSize, "Not our memory!");
		bucket = cast(Bucket(oldSize)) buckets[oldSize];
		oldRef := unallocRef(bucket, oldMemory);
		memcpy(ref.item, oldRef.item, 1<<oldSize);	// @Speed: if the requested size lots smaller than bucket's size we are copying more than we need.  Not sure we care.
	}

	return ref.item;
}

free(using bucketAllocator: *BucketAllocator, oldMemory: *void) {
	oldSize := findBucket(bucketAllocator, oldMemory);
	assert(oldSize, "Not our memory!");
	bucket = cast(Bucket(oldSize)) buckets[oldSize];
	unallocRef(bucket, oldMemory);
}

findBucket(using bucketAllocator: *BucketAllocator, memory: *void) -> int {
	// :MetaSizing Can we be smarter about this with #insert?
	for 4..12 {
		bucket = cast(BucketSet(it)) buckets[it - 4];
		//TEST: this end logic:
		if memory >= *bucket.items[0] && memory < *bucket.items[0] + SIZES_CONFIG[it]  return it;
	}
	return 0;
}

unallocRef(using bucket: *Bucket($T), memory: *void) -> *BucketRef(T) {
	// @Speed: finding the allocated bucket is O(n)...
	ref := usedList;
	prev: *BucketRef(T);
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
	buckets : [9] *BucketSet;
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
