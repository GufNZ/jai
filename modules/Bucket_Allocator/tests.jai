#import "Basic";
#import "Bucket_Allocator"()(SIZES_CONFIG = int.[10,10,10,10], USE_UNMAPPING_ALLOCATOR = true, HONOUR_REALLOC_SHRINK = true, RECORD_STATS = true);

#run main();

main :: () {
	newContext := context;
	newContext.allocator = make_bucket_allocator();

	ba : *BucketAllocator = xx newContext.allocator.data;
	print_stats(ba, compact=true);
	print_stats(ba);
	caps, name := get_capabilities(newContext.allocator);
	print("\n%; %\n\n", name, caps);

	push_context newContext {
		testAllocations();
	}

	baType: *Type_Info_Struct = xx type_info(BucketAllocator);
	context.print_style.default_format_int = .{base=16,minimum_digits=2};
	context.print_style.default_format_struct = .{use_long_form_if_more_than_this_many_members=-1,use_newlines_if_long_form=true};

	for 0..3 {
		fName := tprint("size%Bucket", formatInt(it + 4, 10, 1));
		field := get_field(baType, fName);
		assert(field != null, tprint("Can't find field '%'!", fName));

		size := 1<<(it+4);
		l := 0;

		start := cast(*u8)ba + field.offset_in_bytes;
		end := start + size*10 - 1;
		print("% (%..%)[%]:\n  ", field.name, start, end, end - start + 1);

		for cast(s64)start..cast(s64)end {
			if !l {
				print("%: ", formatInt(it, 16));
			}
			print("%", formatInt((cast(*u8)it).*, 16, 2));
			l += 1;
			if l == size {
				l = 0;
				print(",\n  ");
			} else if l & 1 == 0 {
				print("_");
			}
		}
		print("\n");
	}

	print_stats(ba, compact=true);
	print_stats(ba);
	print("\n%\n\n", tests);
}

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
	.{size = 16},		// A; will overflow to size5.
	.{mode = .FREE, modifyIndex = 3},
	.{mode = .FREE, modifyIndex = 7},
	.{size = 11},		// D
	.{size = 12},		// E
	.{mode = .FREE, modifyIndex = 1},
	.{size = 13},		// 10
	.{mode = .FREE, modifyIndex = 0},
	.{size = 14},		// 12
	.{mode = .FREE, modifyIndex = 2},
	.{size = 15},		// 14
	.{mode = .FREE, modifyIndex = 4},
	.{mode = .FREE, modifyIndex = 9},
	.{mode = .FREE, modifyIndex = 5},
	.{mode = .FREE, modifyIndex = 6},
	.{mode = .FREE, modifyIndex = 8},
	.{size = 16},		// 1A
	.{size = 17},		// 1B
	.{size = 18},		// 1C
	.{size = 19},		// 1D
	.{size = 60},		// 1E
	.{mode = .RESIZE, size = 22, modifyIndex = 0x1B},	// 1F
	.{mode = .RESIZE, size = 32, modifyIndex = 0x1C},	// 20
	.{mode = .RESIZE, size = 33, modifyIndex = 0x1D},	// 21
	.{mode = .RESIZE, size = 30, modifyIndex = 0x1E},	// 22
];

testAllocations :: () {
	ba : *BucketAllocator = xx context.allocator.data;
	other: *Test = ---;
	for * tests {
		if it.mode == {
			case .ALLOCATE;
				it.data = alloc(it.size);
				memset(it.data, xx it_index, it.size);
				write_string(tprint(" ALLOC(%) = %\n", it.size, it.data));
			case .FREE;
				//debug_break();
				other = *tests[it.modifyIndex];
				write_string(tprint("  FREE(%) [%]\n", other.data, other.size));
				free(other.data);
				other.data = xx other.data.*;
			case .RESIZE;
				other = *tests[it.modifyIndex];
				write_string(tprint("RESIZE(%) [%] -> [%] = ", other.data, other.size, it.size));
				it.data = realloc(other.data, it.size, other.size);
				index : u8 = xx it_index;
				for i: 0..it.size {
					it.data[i] += index;
				}
				write_string(tprint("%\n", it.data));
		}
	}
}

Test :: struct {
	mode := Allocator_Mode.ALLOCATE;
	size: int = -1;
	data: *u8;
	modifyIndex := -1;
}
