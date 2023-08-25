#import "Basic";
#import "Bucket_Allocator"()(SIZES_CONFIG = .[10,10,10,10], USE_UNMAPPING_ALLOCATOR = true, HONOUR_REALLOC_SHRINK = true, RECORD_STATS = true);

#run main();

main :: () {
	print("Jai Tests\n");
	newContext := context;
//debug_break();
	newContext.allocator = makeBucketAllocator();

	push_context newContext {
		testAllocations();
	}
}

testAllocations :: () {
	ba : *BucketAllocator = xx context.allocator.data;
	printStats(ba);
}
