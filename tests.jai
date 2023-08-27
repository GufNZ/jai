#import "Basic";
#import "Bucket_Allocator"()(SIZES_CONFIG = int.[10,10,10,10], USE_UNMAPPING_ALLOCATOR = true, HONOUR_REALLOC_SHRINK = true, RECORD_STATS = true);

#run main();

main :: () {
	print("Jai Tests\n");
	newContext := context;
	newContext.allocator = makeBucketAllocator();

	push_context newContext {
		testAllocations();
	}
}

testAllocations :: () {
	ba : *BucketAllocator = xx context.allocator.data;
//debug_break();
	printStats(ba);
}
