#if 1 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false});
		main();
	}
}

part2 := false;

LOG10: float;
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

	if args[0] == "2" {
		part2 = true;
	}

	short_name :: "Data";
	start_file(*handler, short_name, args[1]);

	if handler.failed  return;

	LOG10 = log(10);
	sum: s64;
	nums: [..]Num;
	symbols: [..]Symbol;
	grid: [..][]int;
	y := -1;
	while true {
		line, found := consume_next_line(*handler);
		if !found break;

		array_add(*grid, NewArray(line.count, int));

		y += 1;
		for 0..line.count - 1 {
			c := line[it];
			if c == #char "."  continue;

			if c >= #char "0" && c <= #char "9" {
				num := string_to_int(advance(line, it));
				array_add(*nums, .{x=it, y=y, num=num});
				len := log10(num);
				for x: it..it + len {
					grid[y][x] = nums.count;
				}
				it += len;
			} else {
				array_add(*symbols, .{x=it, y=y, c=line[it]});
			}
		}
	}
	for nums {
		print("%: (%, %) = %\n", it_index, it.x, it.y, it.num);
	}
	ids: Table(int, int);
	for * symbols {
		for y: max(0, it.y - 1)..min(grid.count - 1, it.y + 1) {
			for x: max(0, it.x - 1)..min(grid[0].count - 1, it.x + 1) {
				id := grid[y][x];
				if id {
					table_set(*ids, id, id);
					if it.c == #char "*" {
						if it.idCount == {
							case 0;
								it.idCount = 1;
								it.a = id;
							case 1;
								if it.a != id {
									it.idCount = 2;
									it.b = id;
								}
							case 2;
								if it.a != id && it.b != id {
									it.idCount = -1;
									it.a = 0;
									it.b = 0;
								}
						}
					}
				}
			}
		}
	}
	for symbols {
		print("%: %(%, %) %[%, %]\n", it_index, ascii(it.c), it.x, it.y, it.idCount, it.a, it.b);
	}
	if !part2 {
		for ids {
			sum += nums[it - 1].num;
		}
	} else {
		for symbols {
			if it.c != #char "*" || it.idCount != 2  continue;
			sum += nums[it.a - 1].num * nums[it.b - 1].num;
		}
	}
	print("\n%\n", sum);
}

log10 :: (n: int) -> int {
	return xx floor(log(cast(float) n) / LOG10);
}

Coords :: struct {
	x, y: int;
}
Num :: struct {
	using #as coords: Coords;
	num: s64;
}
Symbol :: struct {
	using #as coords: Coords;
	c: u8;
	idCount: int;
	a: int;
	b: int;
}

#import "Basic";
#import "Compiler";
#import "Debug";
#import "Hash_Table";
#import "Math";
#import "String";
#import "Text_File_Handler";

ascii :: (num: u8) -> string #expand {
	// must be a macro or *num gets invalidated after return
	return .{1, *num};
}
