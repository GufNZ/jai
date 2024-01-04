#if 1 {
	#run start();
	start :: () {
		set_build_options_dc(.{do_output=false});
		main();
	}
}

part2 := false;
stop := false;

Cubes :: struct {
	red, green, blue: int;
}

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

	sum: s64;
	while true {
		line, found := consume_next_line(*handler);
		if !found break;

		//print("------- %\n", line);
		advance(*line, 5);
		num, success, remainder := string_to_int(line);
		print("%, %, '%'\n", num, success, remainder);
		assert(remainder[0] == #char ":");
		advance(*remainder, 2);
		if !part2 {
			ok := true;
			//print("'%'\n", remainder);
			while ok {
				found, left, right := split_from_left(remainder, #char ";");
				//print("%, '%', '%'\n", found, left, right);
				if found {
					ok &= processGame(left);
					remainder = right;
				} else {
					ok &= processGame(remainder);
					break;
				}
			}
			if ok {
				sum += num;
			}
		} else {
			cubes: Cubes;
			while true {
				found, left, right := split_from_left(remainder, #char ";");
				//print("%, '%', '%'\n", found, left, right);
				if found {
					processGame(left, *cubes);
					remainder = right;
				} else {
					processGame(remainder, *cubes);
					break;
				}
			}
			r := cubes.red * cubes.green * cubes.blue;
			sum += r;
			print("  % >> %\n", r, sum);
		}
	}
	print("\n%\n", sum);
}

processGame :: (game: string) -> bool {
	parts := split(game, ",");
	//print("%\n", parts);
	for parts {
		s := trim(it);
		num, success, colour := string_to_int(s);
		//print("'%', %, %, '%'\n", s, num, success, colour);
		assert(success);
		if eat_spaces(colour) == {
			case "red";
				if num > 12 {
					//print("NO: %\n", colour);
					return false;
				}
			case "green";
				if num > 13 {
					//print("NO: %\n", colour);
					return false;
				}
			case "blue";
				if num > 14 {
					//print("NO: %\n", colour);
					return false;
				}
			case;
				assert(false, colour);
		}
	}
	//print("Yes\n");
	return true;
}
processGame :: (game: string, cubes: *Cubes) {
	parts := split(game, ",");
	for parts {
		s := trim(it);
		num, success, colour := string_to_int(s);
		//print("'%', %, %, '%'\n", s, num, success, colour);
		assert(success);
		if eat_spaces(colour) == {
			case "red";
				if num > cubes.red {
					//print("NO: %\n", colour);
					cubes.red = num;
				}
			case "green";
				if num > cubes.green {
					//print("NO: %\n", colour);
					cubes.green = num;
				}
			case "blue";
				if num > cubes.blue {
					//print("NO: %\n", colour);
					cubes.blue = num;
				}
			case;
				assert(false, colour);
		}
	}
}

#import "Basic";
#import "Compiler";
#import "Debug";
#import "String";
#import "Text_File_Handler";

ascii :: (num: u8) -> string #expand {
	// must be a macro or *num gets invalidated after return
	return .{1, *num};
}
