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

	times: [..]int;
	dists: [..]int;
	advance(*line, 9);
	while line {
		line = eat_spaces(line);
		num:, success:, line = string_to_int(line);
		array_add(*times, num);
	}

	line, found = consume_next_line(*handler);
	advance(*line, 9);
	while line {
		line = eat_spaces(line);
		num:, success:, line = string_to_int(line);
		array_add(*dists, num);
	}

	sum := 1;
	for 0..times.count-1 {
		sum *= doRace(times[it], dists[it]);
	}
	print("%\n", sum);
}

doRace :: (time: int, dist: int) -> int {
	/*
		-s^2 + ts -d = 0
		s^2 - ts +d = 0
		s^2 - ts = -d
		s^2 - ts + (t/2)^2 = -d +(t/2)^2

	*/
	/*
	d = speed * (time-speed)
	d > dist:
	speed * (time-speed) > dist
	speed * (time-speed) - dist > 0
	speed*time-speed^2-dist > 0
	-s^2 + t.s - d: a=-1, b=t, c=-d
	-b +- v/ b^2 -4ac / 2a
	-t +- v/ t^2 -d / -2
	*/
	rootOver: float64 = xx (time*time - 4*dist);
	//if rootOver < 0 {		-- don't need or there'd be a race we can't win and the product would collapse to 0.
	//	return 0;
	//}
	firstRoot := (-time + sqrt(rootOver)) / -2;
	secondRoot := (-time - sqrt(rootOver)) / -2;
	return xx abs(floor(firstRoot) - ceil(secondRoot)) - 1;
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
