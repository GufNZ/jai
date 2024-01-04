#if 0 {
	#run go();
	go :: () {
		set_build_options_dc(.{do_output=false, });
		main();
	}
}

part2 := false;

PARALLEL :: true;
MAX_THREADS :: 100;

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

	sum := 0;
	#if PARALLEL {
		l : u16 = 0;
		while found {
			defer l += 1;
			workStorage[l].id = l;
			workStorage[l].line = line;
			line, found = consume_next_line(*handler);
		}
		debug("%\n", array_view(workStorage, 0, l));
		#import "System";
		#import "Thread";

		num_cpus := get_number_of_processors();
		assert(num_cpus < MAX_THREADS);
		thread_group: Thread_Group;
		init(*thread_group, num_cpus, doWork);
		for * thread_group.worker_info {
			it.thread.data = xx (it_index + 1);
		}
		start(*thread_group);
		for 0..l - 1 {
			debug("%: %\n", it, it);
			add_work(*thread_group, *workStorage[it], sprint("Work item %", it + 1));
		}
		while l {
			sleep_milliseconds(10);
			results := get_completed_work(*thread_group);
			for results {
				work := cast(*Work)it;
				print("[%] %: %\n", l, work.id, work.score);
				sum += work.score;
				l -= 1;
			}
			reset_temporary_storage();
		}
		shutdown(*thread_group);
	} else {
		l := 1;
		while found {
			n := matches(line, 0);
			print("%: %\n", l, n);
			l += 1;
			sum += n;
			//stop = true;
			line, found = consume_next_line(*handler);
		}
	}
	print("\n%\n", sum);
}

#if PARALLEL {
	doWork :: (group: *Thread_Group, thread: *Thread, params: *void) -> Thread_Continue_Status {
		work := cast(*Work) params;
		work.score = matches(work.line, xx (cast(int)thread.data));
		reset_temporary_storage();
		return .CONTINUE;
	}
	Work :: struct {
		id: u16;
		line: string;
		score: int;
	}

	workStorage: [1000]Work;
}

stop := false;
brk :: () #expand {
	if stop  debug_break();
}
out := false;
debug :: (s: string, args: ..Any) #expand {
	if out  print(s, ..args);
}

matches :: (line: string, id: u16) -> int {
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
	currentNums[id] = nums;
	if current[id]  free(current[id]);
	current[id] = copy_string(pattern);
	array_reset(*offsets[id]);
	score := test(pattern, nums, min, 0, id);
	if part2 {
		free(parts[0]);
		free(parts[1]);
	}
	return score;
}

FAST :: true;

current: [MAX_THREADS]string;
currentNums: [MAX_THREADS][]s8;
offsets: [MAX_THREADS][..]int;
confirm :: (id: u16) -> int {
	//out = true;
	debug("[%] Confirm '%' against %::%\n[%1]         ", id, current[id], offsets[id], currentNums[id]);
	//stop = current == "?????????????.#..";
	brk();
	i := 0;
	score := 1;
	for o, x: offsets[id] {
		for n: 0..o - 1 {
			if current[id][i + n] == #char "#" {
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
		i += o + currentNums[id][x] + 1;
		for 1..currentNums[id][x]  debug("#");
		debug(".");
		brk();
	}
	brk();
	for i..current[id].count - 1 {
		if current[id][it] == #char "#" {
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
	//out = false;
	return score;
}

INDENT :: "                                                                       ";

test :: (pattern: string, nums: []s8, min: s8, depth: u8, id: u16) -> int {
	debug("%test % against % (%)\n", slice(INDENT, 0, depth), pattern, nums, min);
	brk();
	if !nums.count  return confirm(id);
	result := 0;
	offset := 0;
	array_add(*offsets[id], 0);
	while pattern.count && min <= pattern.count {
		offsets[id][offsets[id].count - 1] = offset;
		result += eval(pattern, nums, min, depth + 1, id);
		debug("%1%2: %\n", slice(INDENT, 0, depth), offset, result);
		brk();
		offset += 1;
		advance(*pattern, 1);
	}
	array_unordered_remove_by_index(*offsets[id], offsets[id].count - 1);
	return result;
}

eval :: (pattern: string, nums: []s8, min: s8, depth: u8, id: u16) -> int {
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
	return test(advance(pattern, num), array_view(nums, 1), min - num, depth + 2, id);
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
