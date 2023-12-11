#if 1 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false, });
		main();
	}
}

part2 := false;

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

	line, found := consume_next_line(*handler);
	if !found return;

	grid: [..][]Dirs;
	y := 0;
	start: Point;
	while found {
		array_add(*grid, NewArray(line.count, Dirs));
		for 0..line.count - 1 {
			grid[y][it] = MAP_OUT[find_index_from_left(MAP_IN, line[it])];
			if grid[y][it] == .ALL {
				start = .{it, y};
			}
		}
		line, found = consume_next_line(*handler);
		y += 1;
	}
	print("%\n", start);
	dump(grid);
	grid[start.y][start.x] = (ifx start.y - 1 >= 0 && grid[start.y - 1][start.x] & .DOWN then .UP)
		| (ifx start.y + 1 < grid.count && grid[start.y + 1][start.x] & .UP then .DOWN)
		| (ifx start.x - 1 >= 0 && grid[start.y][start.x - 1] & .RIGHT then .LEFT)
		| (ifx start.x + 1 < grid[0].count && grid[start.y][start.x + 1] & .LEFT then .RIGHT);

	print("%\n", grid[start.y][start.x]);
	dump(grid);

	context.assertion_failed = logAssert;

	sum := solve(grid, start);
	dump(grid);
	print("\n%\n", sum);

	if part2 {
		sum = 0;
		grid[start.y][start.x] |= 16;
		for y: 0..grid.count - 1 {
			in := false;
			/*
				hit wall /\|/: in = !in
				hit wall /F-+J/: in = !in
				hit wall /L-+7/: in = !in
				hit wall /[FL]-+[7J]/: nop
				!wall: sum += in.
			*/
			x := 0;
			while x < grid[0].count {
				defer x += 1;
				isWall := grid[y][x] >> 4;
				d := grid[y][x] & 15;
				grid[y][x] = d | xx ifx isWall 16;
				if isWall {
					if d == {
						case .DOWN|.RIGHT; {
							x += 1;
							print("+");
							while grid[y][x] & 15 == .LEFT|.RIGHT {
								x += 1;
								print("+");
							}
							in = ifx grid[y][x] & 15 == .DOWN|.LEFT then in else !in;
						}
						case .UP|.RIGHT; {
							x += 1;
							print("+");
							while grid[y][x] & 15 == .LEFT|.RIGHT {
								x += 1;
								print("+");
							}
							in = ifx grid[y][x] & 15 == .UP|.LEFT then in else !in;
						}
						case .UP|.DOWN; {
							in = !in;
						}
						case; assert(false, "Shouldn't get here: %", d);
					}
				} else if in {
					sum += 1;
					grid[y][x] = d | xx ifx isWall 32+16 else 32;
				}
				print(ifx in then (ifx grid[y][x] & 32 then (ifx grid[y][x] & 16 "*" else "#") else "+") else ".");
			}
			print("\n");
		}
		print("\n% in\n", sum);
	}
}

logAssert := (loc: Source_Code_Location, message: string) -> bool {
	print("%\n", type_of(loc));
	print("%:%,% %\n", loc.fully_pathed_filename, loc.line_number, loc.character_number, message, to_standard_error = true);
	return true;
}

solve :: (grid: [][]Dirs, start: Point) -> int {
	delta: Table(Dirs, Point);
	init(*delta);
	table_add(*delta, .UP, .{y=-1});
	table_add(*delta, .LEFT, .{x=-1});
	table_add(*delta, .DOWN, .{y=1});
	table_add(*delta, .RIGHT, .{x=1});

	a, b := start, start;
	aDir, bDir := split(grid[start.y][start.x]);
	print("%\t%\n", aDir, bDir);
	end := false;
	step := 0;
	while !end {
		step += 1;
		print("% %\t% %\t%\n", a, aDir, b, bDir, step);
		aa, f := table_find(*delta, aDir);
		assert(f, "Failed to point %", aDir);
		bb:, f = table_find(*delta, bDir);
		assert(f, "Failed to point %", bDir);
		a += aa;
		b += bb;
		aDir = bounce(aDir, grid[a.y][a.x]);
		bDir = bounce(bDir, grid[b.y][b.x]);
		grid[a.y][a.x] |= xx step << 4;
		grid[b.y][b.x] |= xx step << 4;
		end = a == b;
	}
	return step;
}

split :: (d: Dirs) -> (Dirs, Dirs) {
	test := Dirs.UP;
	a: Dirs;
	while !(d & test) {
		test <<= 1;
	}
	return test, d & ~test;
}

bounce :: (d: Dirs, p: Dirs) -> Dirs {
	//print("bounce(%, %) = %\n", d, p, p & flip(d));
	return p & flip(d);
}

flip :: (d: Dirs) -> Dirs {
	if d == {
		case .UP; return ~.DOWN;
		case .DOWN; return ~.UP;
		case .LEFT; return ~.RIGHT;
	}
	return ~.LEFT;
}

dump :: (grid: [][]Dirs) {
	for y: 0..grid.count - 1 {
		for x: 0..grid[0].count - 1 {
			s, i := array_find(MAP_OUT, grid[y][x] & 15);
			assert(s, "[%, %] % (%)", x, y, grid[y][x] & 15, grid[y][x]);
			print("%", PRINT_MAP[i]);
		}
		print("\t");
		for x: 0..grid[0].count - 1 {
			print("%", (cast(int)grid[y][x])>>4);
		}
		print("\n");
	}
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

Dirs :: enum_flags int {
	NONE :: 0;
	UP :: 1;
	LEFT :: 2;
	DOWN :: 4;
	RIGHT :: 8;
	ALL :: 15;
}

NONE := #char ".";
UD := #char "|";
LR := #char "-";
UR := #char "L";
UL := #char "J";
DL := #char "7";
DR := #char "F";
START := #char "S";

MAP_IN :: ".|-LJ7FS";
PRINT_MAP :: string.["·", "║", "═", "╚", "╝", "╗", "╔", "┼"];
MAP_OUT :: Dirs.[.NONE, .UP|.DOWN, .LEFT|.RIGHT, .UP|.RIGHT, .UP|.LEFT, .DOWN|.LEFT, .DOWN|.RIGHT, .ALL];

#import "Basic";
#import "Compiler";
#import "Debug";
#import "Hash_Table";
#import "Math";
#import "Sort";
#import "String";
#import "Text_File_Handler";

ascii :: (num: u8) -> string #expand {
	// must be a macro or *num gets invalidated after return
	str: string;
	str.count = 1;
	str.data  = *num;
	return str;
}
