#if 0 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false, });
		main();
	}
}

part2 := false;

main :: () {
	//context.assertion_failed = logAssert;
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

	l := 1;
	sum := 0;
	while found {
		n := matches(line);
		print("%: %\n", l, n);
		l += 1;
		sum += n;
		//stop = true;
		line, found = consume_next_line(*handler);
	}
	print("\n%\n", sum);
}

stop := false;
brk :: () #expand {
	if stop  debug_break();
}
out := false;
debug :: (s: string, args: ..Any) #expand {
	if out  print(s, ..args);
}

matches :: (line: string) -> int {
	debug("\n---------------\n");
	parts := split(line, " ");
	if part2 {
		parts[0] = sprint("%1?%1?%1?%1?%1", parts[0]);
		parts[1] = sprint("%1,%1,%1,%1,%1", parts[1]);
	}
	pattern := parts[0];
	numStrs := split(parts[1], ",");
	nums := NewArray(numStrs.count, s8);
	for numStrs {
		nums[it_index] = xx string_to_int(it);
	}

	min : s8 = xx (nums.count - 1);
	for nums {
		min += it;
	}

	//out = pattern == "?###????????";
	currentNums = nums;
	if current  free(current);
	current = copy_string(pattern);
	array_reset(*offsets);
	score := test(pattern, nums, min, 0);
	if part2 {
		free(parts[0]);
		free(parts[1]);
	}
	return score;
}

FAST :: true;

current: string;
currentNums: []s8;
offsets: [..]int;
confirm :: () -> int {
	//out = true;
	debug("Confirm '%' against %::%\n         ", current, offsets, currentNums);
	//stop = current == "?????????????.#..";
	brk();
	i := 0;
	score := 1;
	for o, x: offsets {
		for n: 0..o - 1 {
			if current[i + n] == #char "#" {
				#if FAST {
					debug("! = 0\n");
					return 0;
				} else {
					debug("!");
					score = 0;
				}
			} else {
				debug("_");
			}
			brk();
		}
		i += o + currentNums[x] + 1;
		for 1..currentNums[x]  debug("#");
		debug(".");
		brk();
	}
	brk();
	for i..current.count - 1 {
		if current[it] == #char "#" {
			#if FAST {
				debug("! = 0\n");
				return 0;
			} else {
				debug("!");
				score = 0;
			}
		} else {
			debug("~");
		}
	}
	debug(" = %\n", score);
	brk();
	out = false;
	return score;
}

INDENT :: "                                                                       ";

test :: (pattern: string, nums: []s8, min: s8, depth: u8) -> int {
	debug("%test % against % (%)\n", slice(INDENT, 0, depth), pattern, nums, min);
	brk();
	if !nums.count  return confirm();
	result := 0;
	offset := 0;
	array_add(*offsets, 0);
	while pattern.count && min <= pattern.count {
		offsets[offsets.count - 1] = offset;
		result += eval(pattern, nums, min, depth + 1);
		debug("%1%2: %\n", slice(INDENT, 0, depth), offset, result);
		brk();
		offset += 1;
		advance(*pattern, 1);
	}
	array_unordered_remove_by_index(*offsets, offsets.count - 1);
	return result;
}

eval :: (pattern: string, nums: []s8, min: s8, depth: u8) -> int {
	debug("%eval % against %\n", slice(INDENT, 0, depth), pattern, nums);
	brk();
	if !nums.count  return 0;
	num := nums[0];
	debug("% % :: %", slice(INDENT, 0, depth), num, pattern.count);
	brk();
	// Enough left?
	if num > pattern.count { debug("\n"); return 0; }
	debug("  % :: %", num, slice(pattern, 0, num));
	brk();
	for 0..num-1 {
		if pattern[it] == #char "." { debug("\n"); return 0; }
	}
	if num < pattern.count {
		debug("  end=");
		brk();
		if pattern[num] == #char "#" { debug("\n"); return 0; }
		debug("good.");
	}
	debug("\n");
	brk();
	if nums.count > 1 {
		debug("% Room for next?", slice(INDENT, 0, depth));
		brk();
		if num == pattern.count  return 0;
		num += 1;
		debug("Ok.\n");
	}

	brk();
	return test(advance(pattern, num), array_view(nums, 1), min - num, depth + 2);
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
