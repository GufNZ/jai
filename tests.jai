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

	caps, name := get_capabilities(context.allocator);
	print("\n%; %\n\n", name, caps);

	tests :: Test.[
		.{size = 1},		// 0
		.{size = 2},		// 1
		.{size = 3},		// 2
		.{size = 4},		// 3
		.{size = 5},		// 4
		.{size = 6},		// 5
		.{size = 7},		// 6
		.{size = 8},		// 7
		.{size = 9},		// 8
		.{size = 10},		// 9
		.{mode = .FREE, modifyIndex = 3},
		.{mode = .FREE, modifyIndex = 7},
		.{size = 11},		// 12
		.{size = 12},		// 13
		.{mode = .FREE, modifyIndex = 1},
		.{size = 13},		// 15
		.{mode = .FREE, modifyIndex = 0},
		.{size = 14},		// 17
		.{mode = .FREE, modifyIndex = 2},
		.{size = 15},		// 19
		.{mode = .FREE, modifyIndex = 4},
		.{mode = .FREE, modifyIndex = 9},
		.{mode = .FREE, modifyIndex = 5},
		.{mode = .FREE, modifyIndex = 6},
		.{mode = .FREE, modifyIndex = 8},
		.{size = 16},		// 25
		.{size = 17},		// 26
		.{size = 18},		// 27
		.{size = 19},		// 28
		.{size = 60},		// 29
		.{mode = .RESIZE, size = 22, modifyIndex = 26},
		.{mode = .RESIZE, size = 32, modifyIndex = 27},
		.{mode = .RESIZE, size = 33, modifyIndex = 28},
		.{mode = .RESIZE, size = 30, modifyIndex = 29},
	];

	other: *Test = ---;
	for * tests {
		if it.mode == {
			case .ALLOCATE;
				it.data = alloc(it.size);
				print(" ALLOC(%) = %\n", it.size, it.data);
			case .FREE;
				//debug_break();
				other = *tests[it.modifyIndex];
				print("  FREE(%) [%]\n", other.data, other.size);
				free(other.data);
				other.data = xx other.data.*;
			case .RESIZE;
				other = *tests[it.modifyIndex];
				print("RESIZE(%) [%] -> [%] = ", other.data, other.size, it.size);
				it.data = realloc(other.data, it.size, other.size);
				print("%\n", it.data);
		}
	}

	printStats(ba);
	print("\n%\n\n", FormatArray.{value=tests, begin_string="[\n\t", separator=",\n\t", end_string="\n]"});
}

Test :: struct {
	mode := Allocator_Mode.ALLOCATE;
	size: int = -1;
	data: *u8;
	modifyIndex := -1;
}
