#if 1 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false, });
		main();
	}
}

part2 := false;

cols: [..]u32;
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
	if !found  return;

	rows: [..]u32;
	width: u8;

	sum := 0;

	//debug_break();
	//assert(3!=parseBits(u32.[0,0,1,1,0,0,0], 0));

	while true {
		if !found  break;
		while found && line {
			num:, width = parseBits(line);
			array_add(*rows, num);
			print("%: % (%)\n", line, FormatInt.{ value=num, base=2, minimum_digits=width }, width);
			line, found = consume_next_line(*handler);
		}
		print("%, %\n", width, rows.count);
		for 0..width - 1 {
			n := combineBits(rows, it);
			print ("%\t%\n", FormatInt.{ value=n, base=2, minimum_digits=rows.count }, n);
			array_add(*cols, n);
		}

		fixOther :: (x: int, mismatch: u32) {
			bit : u32 = xx pow(2.0, cast(float64) x);
			offset : int = xx (log(xx mismatch)/log(2.0)); cols[offset] ^= bit;
		};
		skip :: (x: int, mismatch: u32) { };
		smudged := false;
		print("rows:\n");
		mRow := findMirrors(rows, *smudged, fixOther) + 1;
		print("\ncols:\n");
		mCol := ifx mRow 0 else findMirrors(cols, *smudged, skip) + 1;
		print("%/%\n", mRow, mCol);
		sum += mCol + 100 * mRow;
		//assert(!part2 || smudged);
		if part2 {
			print("rows:\n");
			for rows {
				print("%\t%\n", FormatInt.{ value=it, base=2, minimum_digits=width }, it);
			}
			print("cols:\n");
			for cols {
				print("%\t%\n", FormatInt.{ value=it, base=2, minimum_digits=rows.count }, it);
			}
		}
		array_reset(*rows);
		array_reset(*cols);
		line, found = consume_next_line(*handler);
		print("\n---------------\n\n");
	}

	print("\n%\n", sum);
}

parseBits :: (line: string) -> (u32, u8) {
	bit : u32 = 1;
	n: u32;
	w: u8;
	for 0..line.count - 1 {
		n |= ifx line[it] == #char "#" bit;
		w += 1;
		bit <<= 1;
	}
	return n, w;
}

combineBits :: (rows: []u32, test: int) -> u32 {
	mask : u32 = xx pow(2.0, cast(float64) test);
	bit : u32 = 1;
	n: u32;
	for rows {
		n |= ifx it & mask bit;
		bit <<= 1;
	}
	return n;
}

smudgeX: int;
smudgeBits: u32;

unsmudge :: (nums: *[]u32, smudged: *bool, fixOther: (int, u32)) {
	if smudged.* {
		print("unsmudge: [%]  = % = %\n", smudgeX, nums.*[smudgeX], FormatInt.{ value=nums.*[smudgeX], base=2, minimum_digits=9 });
		nums.*[smudgeX] ^= smudgeBits;
		print("unsmudge: [%] := % = %\n", smudgeX, nums.*[smudgeX], FormatInt.{ value=nums.*[smudgeX], base=2, minimum_digits=9 });
		fixOther(smudgeX, smudgeBits);
		smudged.* = false;
	}
}

equal :: (nums: *[]u32, x: int, y: int, smudged: *bool, fixOther: (int, u32)) -> bool {
	if !part2 {
		//print("part1: [%]% == [%]% = %\n", x, nums.*[x], y, nums.*[y], nums.*[x] == nums.*[y]);
		return nums.*[x] == nums.*[y];
	}

	mismatch := nums.*[x] ^ nums.*[y];
	if !mismatch  return true;
	if smudged.* {
		unsmudge(nums, smudged, fixOther);
		return false;
	}

	bits: u8;
	#asm {
		popcnt.d bits, mismatch;
	}
	if bits == 1 {
		print("part2: [%]% == [%]% = %\n", x, nums.*[x], y, nums.*[y], FormatInt.{ value=nums.*[x] ^ nums.*[y], base=2, minimum_digits=9 });
		nums.*[x] ^= mismatch;
		print("[%] := %\n", x, nums.*[x]);
		fixOther(x, mismatch);
		smudged.* = true;
		smudgeX = x;
		smudgeBits = mismatch;
		return true;
	}

	unsmudge(nums, smudged, fixOther);
	return false;
}

findMirrors :: (nums: []u32, smudged: *bool, fixOther: (int, u32)) -> int {
	for test: 0..nums.count - 2 {
		print("%: %==% = %\n", test, nums[test], nums[test+1], nums[test] == nums[test+1]);
		if !equal(*nums, test, test+1, smudged, fixOther)  continue;
		a := test - 1;
		b := test + 2;
		print("%: [%]% == [%]% = %\n", test, a, ifx a >= 0 nums[a] else -1, b, ifx b < nums.count nums[b] else -1, ifx a >= 0 && b < nums.count then nums[a] == nums[b] else false);
		while a >= 0 && b < nums.count && equal(*nums, a, b, smudged, fixOther) {
			a -= 1;
			b += 1;
			print("%: [%]% == [%]% = %\n", test, a, ifx a >= 0 nums[a] else -1, b, ifx b < nums.count nums[b] else -1, ifx a >= 0 && b < nums.count then nums[a] == nums[b] else false);
		}
		print("-1 :: %, % :: %\n", a, b, nums.count);
		if a == -1 || b == nums.count {
			print("Matched %\n", test);
			return test;
		}
	}
	print("No Match\n");
	return -1;
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
	return .{1, *num};
}
