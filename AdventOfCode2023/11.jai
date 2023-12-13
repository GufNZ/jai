#if 1 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false, });
		main();
	}
}

main :: () {
	args: []string;
	if #compile_time {
		options := get_build_options();
		args = options.compile_time_command_line;
		print("CompileTime args: %\n", args);
	} else {
		args = get_command_line_arguments();
		args.data += 1;
		args.count -= 1;
		print("RunTime args: %\n", args);
	}

	handler: Text_File_Handler;
	defer deinit(*handler);
	handler.do_version_number = false;
	handler.strip_comments_from_ends_of_lines = false;
	handler.auto_skip_blank_lines = false;
	handler.comment_character = 0;

	sizeMul, success := string_to_int(args[0]);
	assert(success);

	short_name :: "Data";
	start_file(*handler, short_name, args[1]);

	if handler.failed  return;

	line, found := consume_next_line(*handler);
	if !found return;

	sum := 0;
	galaxies: [..]Galaxy;
	colCounts := NewArray(line.count, int);
	rowCounts: [..]int;
	y := 0;
	id : u16 = 0;
	while found {
		rowCount := 0;
		for 0..line.count - 1 {
			if line[it] == #char "#" {
				rowCount += 1;
				colCounts[it] += 1;
				id += 1;
				galaxy := array_add(*galaxies);
				galaxy.x = it;
				galaxy.y = y;
				galaxy.id = id;
			}
		}
		array_add(*rowCounts, rowCount);
		y += 1;
		line, found = consume_next_line(*handler);
	}
	w := colCounts.count;
	h := rowCounts.count;
	print("%x%\n", w, h);
	dump(w, h, galaxies);

	offset(*colCounts, sizeMul);
	offset(*rowCounts, sizeMul);
	for a: 0..galaxies.count - 2 {
		for b: a+1..galaxies.count - 1 {
			sum += manhattan(colCounts, rowCounts, galaxies[a], galaxies[b]);
		}
	}
	print("\n%\n", sum);
}

dump :: (w: int, h: int, galaxies: []Galaxy) {
	for y: 0..h - 1 {
		for x: 0..w - 1 {
			found: u16;
			for galaxies {
				if it.x == x && it.y == y {
					found = it.id;
					break;
				}
			}
			if found {
				print("%", found);
			} else {
				print(".");
			}
		}
		print("\n");
	}
}

offset :: (nums: *[]int, mul: int) {
	print("%\n", nums.*);
	running := 0;
	for * nums.* {
		r := running;
		running += ifx it.* 0 else mul-1;
		it.* = it_index + r;
	}
	print("%\n\n", nums.*);
}

manhattan :: inline (colCounts: []int, rowCounts: []int, a: Point, b: Point) -> int {
	x := abs(colCounts[a.x] - colCounts[b.x]);
	y := abs(rowCounts[a.y] - rowCounts[b.y]);
	n := x + y;
	//print("% -> % = % + % = %\n", a, b, x, y, n);
	return n;
}

Galaxy :: struct {
	using #as p: Point;
	id: u16;
}

Point :: struct {
	x: int;
	y: int;
}
operator == :: (a: Point, b: Point) -> bool {
	return a.x == b.x && a.y == b.y;
}
operator + :: (a: Point, b: Point) -> Point {
	return .{a.x+b.x, a.y+b.y};
}

#import "Basic";
#import "Compiler";
#import "Debug";
#import "Hash_Table";
#import "Math";
#import "Sort";
#import "String";
#import "Text_File_Handler";

logAssert := (loc: Source_Code_Location, message: string) -> bool {
	print("%\n", type_of(loc));
	print("%:%,% %\n", loc.fully_pathed_filename, loc.line_number, loc.character_number, message, to_standard_error = true);
	return true;
}

ascii :: (num: u8) -> string #expand {
	// must be a macro or *num gets invalidated after return
	str: string;
	str.count = 1;
	str.data  = *num;
	return str;
}
