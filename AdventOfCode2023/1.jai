#if 1 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false});
		main();
	}
}

numbers :: string.[
	"zero",
	"one",
	"two",
	"three",
	"four",
	"five",
	"six",
	"seven",
	"eight",
	"nine"
];

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
	while true {
		line, found := consume_next_line(*handler);
		if !found break;

		num: int;

		for 0..line.count-1 {
			//print("%:%\n", it, ascii(line[it]));
			num1, found := find(line, it);
			if found {
				num = num1 * 10;
				break;
			}
		}
		for < line.count-1..0 {
			//print("%:%\n", it, ascii(line[it]));
			num2, found := find(line, it);
			if found {
				num += num2;
				4;
			}
		}
		print("------ %\n", num);
		sum += num;
	}

	print("%\n", sum);
}

find :: (line: string, index: int) -> num: int, found := true {
	//print("%:% (%, %)\t", index, ascii(line[index]), line[index] >= #char "0", line[index] <= #char "9");
	if (line[index] >= #char "0" && line[index] <= #char "9") {
		//print("%\n", line[index] - #char "0");
		return line[index] - #char "0";
	}

	if (part2) {
		s := advance(line, index);
		//print("%: %\n", index, s);
		for numbers {
			if begins_with(s, it) {
				return it_index;
			}
		}
	}

	//print("\n");
	return -1, false;
}

#import "Basic";
#import "Compiler";
#import "String";
#import "Text_File_Handler";

ascii :: (num: u8) -> string #expand {
	// must be a macro or *num gets invalidated after return
	return .{1, *num};
}
