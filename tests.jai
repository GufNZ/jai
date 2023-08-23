#import "Basic";
#import "Bucket_Allocator"()(USE_UNMAPPING_ALLOCATOR = true, HONOUR_REALLOC_SHRINK = true, RECORD_STATS = true);

main :: () {
	print("Jai Tests\n");

	newContext := context;
	newContext.allocator = makeBucketAllocator();

	push_context newContext {
		testAllocations();
	}
}

testAllocations :: () {
}
