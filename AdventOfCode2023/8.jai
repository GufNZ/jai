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

	steps := line;
	line, found = consume_next_line(*handler);
	nodes: Table(string, *Node);
	init(*nodes);
	line, found = consume_next_line(*handler);
	while found {
		print(">%\n", line);
		parts := split(line, " ");
		newNode:, found = table_find(*nodes, parts[0]);
		if !found {
			//print("newNode %\n", parts[0]);
			newNode = New(Node);
			newNode.id=parts[0];
			table_add(*nodes, newNode.id, newNode);
		}
		l := advance(parts[2], 1);
		l.count -= 1;
		r := parts[3];
		r.count -= 1;
		lNode:, found = table_find(*nodes, l);
		if !found {
			//print("newL %\n", l);
			lNode = New(Node);
			lNode.id = l;
			table_add(*nodes, l, lNode);
		}
		rNode:, found = table_find(*nodes, r);
		if !found {
			//print("newR %\n", r);
			rNode = New(Node);
			rNode.id = r;
			table_add(*nodes, r, rNode);
		}
		newNode.left = lNode;
		newNode.right = rNode;
		//print("%=%\n", newNode, newNode.*);
		line, found = consume_next_line(*handler);
	}
	//for nodes {
	//	print("%: % %\n", it, it_index, it.*);
	//}

	step := 0;
	sum := 0;
	if !part2 {
		at := "AAA";

		while at != "ZZZ" {
			node:, found = table_find(*nodes, at);
			assert(found);
			//print("% -[%]> ", at, ascii(steps[step]));
			at = ifx steps[step] == #char "L" then node.left.id else node.right.id;
			//print("%\n", at);
			sum += 1;
			step += 1;
			if step == steps.count {
				step = 0;
			}
		}
	} else {
		ats: [..]string;
		for nodes {
			if it.id[2] == #char "A" {
				array_add(*ats, it.id);
			}
		}
		print("%\n", ats);
		zCount := 0;
		//paths: [6]Table(string, int);
		//for * paths {
		//	init(it);
		//}
		lens: [6]int;
		for ats {
			reset_temporary_storage();
			at := it;
			step = 0;
			for i: 1..3 {
				first := true;
				sum = 0;
				while first || at[2] != #char "Z" {
					first = false;
					node:, found = table_find(*nodes, at);
					assert(found);
					//print("% -[%]> ", at, ascii(steps[step]));
					at = ifx steps[step] == #char "L" then node.left.id else node.right.id;
					//print("%\n", at);
					step += 1;
					sum += 1;
					if step == steps.count {
						step = 0;
					}
				}
				print("path % len is %\n", i, sum);
				// Turns out the loop starts different to the first path but is the same length.
				lens[it_index] = sum;
			}
			print("\n");
		}
		sum = lcm(..lens);
	}
	print("\n%\n", sum);
}

gcd :: (_a: int, _b: int) -> int {
	a, b := _a, _b;
	while b {
		a, b = b, a % b;
	}
	return a;
}

lcm :: (a: int, b: int) -> int {
	return a * b / gcd(a, b);
}
lcm :: (n: ..int) -> int{
	r := n[0];
	for 1..n.count - 1 {
		r = lcm(r, n[it]);
	}
	return r;
}

Node :: struct {
	id: string;
	left: *Node;
	right: *Node;
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
	str: string;
	str.count = 1;
	str.data  = *num;
	return str;
}
