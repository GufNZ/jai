#import "Compiler";
#import "Basic";
#import "Hash_Table";
#import "Sort";

main :: () {
	ops :: #run -> []Operator_Type {
		ops : [..]Operator_Type;
		for type_info(Operator_Type).values {if xx it == Operator_Type.POINTER_DEREFERENCE break; array_add(*ops, xx it);}
		for int.[#char "+", #char "-", #char "*", #char "/", #char "<", #char ">", #char "=", #char "&", #char "|", #char "^", #char ".", #char "%"] array_add(*ops, xx it);
		return ops;
	}

	OP_COUNT :: 1 + #run enum_highest_value(Operator_Type);
	op_cmp_chart :: #run -> [OP_COUNT][OP_COUNT]s8 {

		op_cmp_chart : [OP_COUNT][OP_COUNT]s8;
		#insert -> string {
			the_code : String_Builder;
			for op0 : ops for op1 : ops {
				if op0 == op1 continue op1;
				print(*the_code, "op_cmp_chart[%1][%2] = op_cmp(cast(Operator_Type,%1), cast(Operator_Type,%2));\n",cast(int,op0),cast(int,op1));
			}
			return builder_to_string(*the_code);
		}
		return op_cmp_chart;
	}

	precedence_classes : Table(Operator_Type, [..]Operator_Type);

	for op : ops {
		for * precedence_classes if op_cmp_chart[op][it_index] == 0 {array_add(it, op); continue op;}
		new_list, actually_new := find_or_add(*precedence_classes, op);
		assert(actually_new);
		array_add(new_list, op);
	}

	sorting_op_cmp :: (op0 : Operator_Type, op1 : Operator_Type) -> int {
		return op_cmp_chart[op0][op1];
	}

	class_reps : [..]Operator_Type;
	for precedence_classes array_add(*class_reps, it_index);

	quick_sort(class_reps, sorting_op_cmp);

	print("The precedence classes are:\n");
	for class_reps {
		_, the_class := table_find(*precedence_classes, it);
		for the_class {
			if it == .MOD_ASSIGN print("\%=");
			else if it == #char "%" print("\%");
			else print(op_to_string(it));
			if it_index == the_class.count-1 print("\n");
			else print(" ");
		}
	}

}


op_to_string :: (op : Operator_Type) -> string {
	if op <= OPERATOR_TYPE_MAX_ASCII_VALUE return copy_string({1, xx *op});
	return operator_to_string(op);
}


op_geq :: ($op0 : Operator_Type, $op1 : Operator_Type) -> bool {

	#insert -> string{return tprint("code_1 := #code {x % y % z;};",op_to_string(op0),op_to_string(op1));}

	block_root := cast(*Code_Block, compiler_get_nodes(code_1));
	op_root := cast(*Code_Binary_Operator, block_root.statements[0]);
	assert(op_root.kind == .BINARY_OPERATOR);

	op_type := op_root.operator_type;

	return ifx op_type <= OPERATOR_TYPE_MAX_ASCII_VALUE
		then op_type == op0
		else operator_to_string(op_type) == operator_to_string(op0);
}

op_cmp :: ($op0 : Operator_Type, $op1 : Operator_Type) -> s8 {
	res := cast(s8, op_geq(op0, op1)) - cast(s8, op_geq(op1, op0));
	return res;
}