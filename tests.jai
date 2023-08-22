#import "Basic";
#import "Bucket_Allocator";

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
