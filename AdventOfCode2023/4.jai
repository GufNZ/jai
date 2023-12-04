#if 1 {
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

	sum: int;
	rows: [199]int;
	for 0..198 {
		rows[it] = 1;
	}
	index := 0;
	while true {
		line, found := consume_next_line(*handler);
		if !found break;

		success, left, right := split_from_left(line, #char ":");
		assert(success);
		right = eat_spaces(right);
		success, left, right = split_from_left(right, #char "|");
		assert(success);
		right = eat_spaces(right);

		score := scoreThese(left, right);
		if !part2 {
			if score {
				//print(" = %, %\n", score, pow(2.0, xx (score - 1)));
				sum += xx pow(2.0, xx (score - 1));
			}
		} else {
			m := rows[index];
			for 1..score {
				rows[index + it] += m;
			}
			sum += m;
		}

		index += 1;
	}
	print("\n%\n", sum);
}

scoreThese :: (left: string, right: string) -> int {
	winning: [..]int;
	have: [..]int;
	readNumbers(*winning, left);
	readNumbers(*have, right);

	score := 0;
	for w: winning {
		for h: have {
			if w == h {
				//print("% ", h);
				score += 1;
				break;
			}
		}
	}
	array_reset(*winning);
	array_reset(*have);
	return score;
}

/*
Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53		: 4
Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19		: 2
Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1		: 2
Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83		: 1
Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36		: 0
Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11		: 0


0:			[1,1,1,1,1,1]
1: 4 *1		[1 ,2,2,2,2,1]
2: 2 *2		[1,2 ,4,4,2,1]
3: 2 *4		[1,2,4, 8,6,1]
4: 1 *8		[1,2,4,8, E,1]
5: 0 *E		[1,2,3,4,E, 1]
6: 0 *1		[1,2,3,4,E,1 ]
*/
readNumbers :: (arr: *[..]int, s: string) {
	r := s;
	while true {
		num:, found:, r = string_to_int(r);
		if !found  return;

		array_add(arr, num);
		r = eat_spaces(r);
	}
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
