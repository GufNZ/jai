#if 0 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false});
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

	advance(*line, 7);

	seeds := parseNums(line);

	line, found = consume_next_line(*handler);
	assert(!line);
	toSoil := parseMap(*handler, "seed-to-soil map:");
	toFertilizer := parseMap(*handler, "soil-to-fertilizer map:");
	toWater := parseMap(*handler, "fertilizer-to-water map:");
	toLight := parseMap(*handler, "water-to-light map:");
	toTemp := parseMap(*handler, "light-to-temperature map:");
	toHumidity := parseMap(*handler, "temperature-to-humidity map:");
	toLocation := parseMap(*handler, "humidity-to-location map:");

	closest := S64_MAX;
	if !part2 {
		for seeds {
			closest = min(closest, map(toLocation, map(toHumidity, map(toTemp, map(toLight, map(toWater, map(toFertilizer, map(toSoil, it))))))));
		}
	} else {
		i := 0;
		while i < seeds.count {
			print("%/% : %..%\n", i, seeds.count/2, seeds[i], seeds[i]+seeds[i+1]-1);
			defer i += 2;
			for seeds[i]..seeds[i]+seeds[i+1]-1 {
				if (it%100000 == 0) print("% : %    \r", it, closest);
				closest = min(closest, map(toLocation, map(toHumidity, map(toTemp, map(toLight, map(toWater, map(toFertilizer, map(toSoil, it))))))));
			}
			print("\n");
		}
	}

	print("\n%\n", closest);
}

Rule :: struct {
	src: int;
	dst: int;
	len: int;
	name: string;
}

map :: (rules: []Rule, src: int) -> int {
	for rules {
		test := map(it, src);
		//print("% %=>[%, %, %]=>%\n", it.name, src, it.src, it.dst, it.len, test);
		if test != -1 {
			return test;
		}
	}
	return src;
}

map :: (r: Rule, src: int) -> int {
	if src >= r.src && src < r.src + r.len {
		//print("  [%..%..%)@% {%} %\n", r.src, src, r.src + r.len, r.dst, src - r.src, r.dst + src - r.src);
		return r.dst + src - r.src;
	}
	return -1;
}

parseMap :: (handler: *Text_File_Handler, mapName: string) -> []Rule {
	line, found := consume_next_line(handler);
	assert(found && line == mapName);
	line, found = consume_next_line(handler);
	rules: [..]Rule;
	while found && line {
		nums := parseNums(line);
		array_add(*rules, .{src=nums[1], dst=nums[0], len=nums[2], name=mapName});
		line, found = consume_next_line(handler);
	}
	return rules;
}

parseNums :: (line: string) -> []int {
	strs := split(line, " ");
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
#import "String";
#import "Text_File_Handler";

ascii :: (num: u8) -> string #expand {
	// must be a macro or *num gets invalidated after return
	str: string;
	str.count = 1;
	str.data  = *num;
	return str;
}
