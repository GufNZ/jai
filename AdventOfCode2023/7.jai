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

	hands: [..]Hand;
	while found {
		array_add(*hands, parseHand(line));
		line, found = consume_next_line(*handler);
	}

	sorted := quick_sort(hands, compareHands);

	sum := 0;
	for sorted {
		score := (it_index + 1) * it.bid;
		sum += score;
		print("%: %\t% * % = %\t%\n", it_index, it, it_index + 1, it.bid, score, sum);
	}
	print("%\n", sum);
}

compareHands :: (a: Hand, b: Hand) -> s8 {
	s : s8 = xx (a.kind - b.kind);
	if s  return s;
	for 0..4 {
		s = a.cards[it] - b.cards[it];
		if s  return s;
	}
	return 0;
}

parseHand :: (line: string) -> Hand {
	h := New(Hand);
	h.str = line;
	memcpy(h.cards.data, line.data, 5);
	advance(*line, 6);
	h.bid = string_to_int(line);
	h.kind = examine(*h.cards);
	print("%\n", h.*);
	return h;
}

CARD_ORDER_1 :: "23456789TJQKA";
CARD_ORDER_2 :: "J23456789TQKA";

Pair :: struct {
	count: u8;
	card: s8;
}

debugCpm :: (a: Pair, b: Pair) -> int {
	s := comparePairs(a, b);
	print("\t%::% = %\n", a, b, s);
	return s;
}

comparePairs :: (a: Pair, b: Pair) -> int {
	s := (cast(int)b.count) - (cast(int)a.count);
	if s  return xx s;
	return xx (b.card - a.card);
}

examine :: (cards: *[5]s8) -> Kind {
	seen: Table(s8, u8);
	init(*seen, 5);
	for cards.* {
		key : s8 = xx find_index_from_left(ifx part2 CARD_ORDER_2 else CARD_ORDER_1, ascii(xx it));
		cards.*[it_index] = key;
		value, found := table_find(*seen, key);
		table_set(*seen, key, ifx found value+1 else 1);
	}

	if part2 {
		J :: 0;
		value, found := table_find(*seen, J);
		if found {
			// find the card we have most of; tie-break by card value
			// replace any J with that.
			print(" = %\n", seen.count);
			pairs: [5]Pair;
			i := 0;
			for seen {
				pairs[i] = .{it, it_index};
				i += 1;
			}
			print(" < %\n", pairs);
			sorted := pairs;
			bubble_sort(sorted, comparePairs);
			print(" > %\n", sorted);
			table_remove(*seen, J);
			// Don't replace J with J!
			replacement := ifx sorted[0].card == J then sorted[1].card else sorted[0].card;
			v, s := table_find(*seen, replacement);
			table_set(*seen, replacement, v+value);
			print(" = %: ", seen.count);
			for seen {
				print("%:%, ", it_index, it);
			}
			print("\n");
		}
	}

	if seen.count == {
		case 1;  return .FIVE_OF_A_KIND;
		case 2; {
			for seen {
				if it == {
					case 4;  return .FOUR_OF_A_KIND;
					case 3;  return .FULL_HOUSE;
				}
			}
		}
		case; {
			pairs := 0;
			for seen {
				if it == {
					case 3;  return .THREE_OF_A_KIND;
					case 2;  pairs += 1;
				}
			}
			if pairs == {
				case 2;  return .TWO_PAIR;
				case 1;  return .ONE_PAIR;
			}
		}
	}
	return .HIGH_CARD;
}

Kind :: enum {
	HIGH_CARD;
	ONE_PAIR;
	TWO_PAIR;
	THREE_OF_A_KIND;
	FULL_HOUSE;
	FOUR_OF_A_KIND;
	FIVE_OF_A_KIND;
}

Hand :: struct {
	str: string;
	cards: [5]s8;
	kind: Kind;
	bid: int;
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
