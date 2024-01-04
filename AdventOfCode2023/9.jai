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

	sum := 0;
	while found {
		n := parseNums(line);
		nn := next(n);
		if part2 {
			print("%, %\n", nn, line);
		} else {
			print("%, %\n", line, nn);
		}
		sum += nn;
		reset_temporary_storage();
		line, found = consume_next_line(*handler);
	}

	print("\n%\n", sum);
}

next :: (nums: []int) -> int {
	diffs := NewArray(nums.count - 1, int);
	prev := nums[0];
	for 1..nums.count - 1 {
		diffs[it - 1] = nums[it] - prev;
		prev = nums[it];
	}
	end := true;
	for diffs {
		if it != 0 {
			end = false;
			break;
		}
	}
	if end {
		return nums[0];
	} else {
		return ifx part2 nums[0] - next(diffs) else nums[nums.count - 1] + next(diffs);
	}
}

parseNums :: (s: string) -> []int {
	strs := split(s, " ");
	nums := NewArray(strs.count, int);
	for strs {
		nums[it_index] = string_to_int(it);
	}
	return nums;
}

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
	return .{1, *num};
}
