#import "Basic";
#import "Compiler";
#import "File_Utilities";
#import "Hash_Table";
#import "String";

NodeKindToNodeType : []Type = .[
	//	UNINITIALIZED				:: 0;
	void,
	//	BLOCK						:: 1;
	Code_Block,
	//	LITERAL						:: 2;
	Code_Literal,
	//	IDENT						:: 3;
	Code_Ident,
	//	UNARY_OPERATOR				:: 4;
	Code_Unary_Operator,
	//	BINARY_OPERATOR				:: 5;
	Code_Binary_Operator,
	//	PROCEDURE_BODY				:: 6;
	Code_Procedure_Body,
	//	PROCEDURE_CALL				:: 7;
	Code_Procedure_Call,
	//	CONTEXT						:: 8;
	Code_Context,
	//	WHILE						:: 9;
	Code_While,
	//	IF							:: 10;
	Code_If,
	//	LOOP_CONTROL				:: 11;
	Code_Loop_Control,
	//	CASE						:: 12;
	Code_Case,
	//	// 13 is currently unused.
	void,
	//	RETURN						:: 14;
	Code_Return,
	//	FOR							:: 15;
	Code_For,
	//
	//	TYPE_DEFINITION				:: 16;
	Code_Type_Definition,
	//	TYPE_INSTANTIATION			:: 17;
	Code_Type_Instantiation,
	//	ENUM						:: 18;
	Code_Enum,
	//
	//	PROCEDURE_HEADER			:: 19;
	Code_Procedure_Header,
	//	STRUCT						:: 20;
	Code_Struct,
	//	COMMA_SEPARATED_ARGUMENTS	:: 21;
	Code_Comma_Separated_Arguments,
	//	EXTRACT						:: 22;
	Code_Extract,
	//	DIRECTIVE_BYTES				:: 23;
	Code_Directive_Bytes,
	//	MAKE_VARARGS				:: 24;
	Code_Make_Varargs,
	//
	//	DECLARATION					:: 25;
	Code_Declaration,
	//
	//	CAST						:: 26;
	Code_Cast,
	//
	//	DIRECTIVE_IMPORT			:: 27;
	Code_Directive_Import,
	//	DIRECTIVE_THIS				:: 28;
	void,	//NOTE: there doesn't seem to be a compiler node for this [yet].
	//	DIRECTIVE_THROUGH			:: 29;
	Code_Directive_Through,
	//	DIRECTIVE_LOAD				:: 30;
	Code_Directive_Load,
	//
	//	DIRECTIVE_RUN				:: 31;
	Code_Directive_Run,
	//	DIRECTIVE_CODE				:: 32;
	Code_Directive_Code,
	//	DIRECTIVE_POKE_NAME			:: 33;
	Code_Directive_Poke_Name,
	//	ASM							:: 34;  // We might reorder this later so it's not in the middle of the directives.
	Code_Asm,
	//	DIRECTIVE_BAKE				:: 35;
	Code_Directive_Bake,
	//	DIRECTIVE_MODIFY			:: 36;
	Code_Directive_Modify,
	//	DIRECTIVE_LIBRARY			:: 37;
	Code_Directive_Library,
	//
	//	EXPRESSION_QUERY			:: 38;
	Code_Expression_Query,
	//	PUSH_CONTEXT				:: 39;
	Code_Push_Context,
	//
	//	NOTE						:: 40;
	Code_Note,
	//
	//	DIRECTIVE_PLACE				:: 41;
	void,	//NOTE: not a thing anymore.
	//	DIRECTIVE_SCOPE				:: 42;
	Code_Directive_Scope,
	//	TYPE_QUERY					:: 43;
	Code_Type_Query,
	//	DIRECTIVE_LOCATION			:: 44;
	Code_Directive_Location,
	//	DIRECTIVE_MODULE_PARAMETERS	:: 45;
	Code_Directive_Module_Parameters,
	//	DIRECTIVE_ADD_CONTEXT		:: 46;
	Code_Directive_Add_Context,
	//	DIRECTIVE_COMPILE_TIME		:: 47;
	void,	//NOTE: unused in Compiler module.
	//
	//	COMPOUND_DECLARATION		:: 48;
	Code_Compound_Declaration,
	//	DEFER						:: 49;
	Code_Defer,
	//	USING						:: 50;
	Code_Using,
	//	PLACEHOLDER					:: 51;
	Code_Placeholder,
	//
	//	DIRECTIVE_INSERT			:: 52;
	Code_Directive_Insert,
	//	DIRECTIVE_PROCEDURE_NAME	:: 53;
	Code_Directive_Procedure_Name,
	//	DIRECTIVE_WILDCARD			:: 54;
	Code_Directive_Wildcard,
	//	DIRECTIVE_EXISTS			:: 55;
	Code_Directive_Exists,
	//	DIRECTIVE_CONTEXT_TYPE		:: 56;
	Code_Directive_Context_Type,
	//
	//	RESOLVED_OVERLOAD			:: 57;
	Code_Resolved_Overload,
	//	DIRECTIVE_OVERLAY			:: 58;
	Code_Directive_Overlay,
];
NodeTypeToNodeKind: Table(Type, NodeKind, given_hash_function=(k) => k.(*Type_Info).(u32,trunc));

CopyEnum :: (enumName: string, src: *Type_Info) -> string {
	b: String_Builder;
	srcInfo := src.(*Type_Info_Enum);
	print(*b, "% :: enum {\n", enumName);
	for srcInfo.names {
		print(*b, "\t% :: %;\n", it, srcInfo.values[it_index]);
	}
	print(*b, "}\n");
	return builder_to_string(*b);
}

#insert #run CopyEnum("NodeKind", type_info(Code_Node.Kind));

unwrapTypechecked :: (typechecked: []Typechecked($T)) -> []*T {
	result: [..]*T;
	for typechecked {
		array_add(*result, it.expression);
	}

	return result;
}


HasNote :: struct {
	notes: [] *Code_Note;
}

hasNote :: (node: *$T/interface HasNote, noteName: string) -> bool {
	for node.notes {
		if it.text == noteName {
			return true;
		}
	}


	return false;
}

hasNotePrefix :: (node: *$T/interface HasNote, notePrefix: string) -> bool {
	for node.notes {
		if starts_with(it.text, notePrefix) {
			return true;
		}
	}


	return false;
}

hasNoteContaining :: (node: *$T/interface HasNote, noteContent: string) -> bool {
	for node.notes {
		if contains(it.text, noteContent) {
			return true;
		}
	}


	return false;
}


filenameIs :: (node: *Code_Node, filename: string) -> bool {
	return path_filename(node.location.enclosing_load.fully_pathed_filename) == filename;
}

pathContains :: (node: *Code_Node, needle: string) -> bool {
	path := parse_path(node.location.enclosing_load.fully_pathed_filename);
	for path.words {
		if it == needle {
			return true;
		}
	}


	return false;
}

//FilterAST :: struct (NodeType: Type, $FilteredNodeType: Type) {
//	startNodes: [..]*NodeType;
//	predicate: (node: *FilteredNodeType) -> bool;
//}

//TransformAST :: struct (NodeType: Type, Kind: int, $FilteredNodeType: Type = void, $TransformedNodeType: Type)
//#modify {
//	FilteredNodeType = NodeKindToNodeType[Kind];
//	return FilteredNodeType != void, tprint("TransformAST: Invalid node kind %", Kind);
//} {
//	startNodes: [..]*NodeType;
//	predicate: (node: *FilteredNodeType) -> bool;
//	transform: (node: *FilteredNodeType) -> *TransformedNodeType;
//}

//nodeKind :: (kind: NodeKind) -> Type {
//	return NodeKindToNodeType[xx kind];
//}

filterASTNodes :: (nodes: []*$NodeType, predicate: (node: *$FilteredNodeType) -> bool) -> []*FilteredNodeType {
	if !NodeTypeToNodeKind.count {
		for NodeKindToNodeType {
			table_add(*NodeTypeToNodeKind, it, xx it_index);
		}
	}

	found, targetKind := table_find(*NodeTypeToNodeKind, FilteredNodeType);
	assert(found, tprint("filterAST: Invalid node type %", FilteredNodeType));

	result: [..]*FilteredNodeType;
	for nodes {
		if it.kind == xx targetKind {
			node := it.(*FilteredNodeType);
			if predicate(node) {
				array_add(*result, node);
			}
		}
	}

	return result;
}

TransformData :: struct (FilteredNodeType: Type, TransformedNodeType: Type) {
	targetKind: NodeKind;
	predicate: (node: *FilteredNodeType) -> bool;
	transform: (node: *FilteredNodeType) -> *TransformedNodeType;
}

transformAST :: (node: *$T/Code_Node, predicate: (node: *$FilteredNodeType) -> bool, transform: (node: *FilteredNodeType) -> *$TransformedNodeType) -> *T {
	if !NodeTypeToNodeKind.count {
		for NodeKindToNodeType {
			table_add(*NodeTypeToNodeKind, it, xx it_index);
		}
	}

	found, targetKind := table_find(*NodeTypeToNodeKind, FilteredNodeType);
	assert(found, tprint("transformAST: Invalid node type %", FilteredNodeType));

	transformData := TransformData(FilteredNodeType, TransformedNodeType).{
		targetKind,
		predicate,
		transform
	};

	return walkAST(
		node,
		transformData,
		(t, candidate) => ifx candidate.kind == xx t.targetKind && t.predicate(candidate.(*FilteredNodeType))
			then t.transform(candidate.(*FilteredNodeType)).(*Code_Node)
			else candidate
	);
}

walkAST :: (node: *$T/Code_Node, userData: $D, handler: (userData: D, node: *Code_Node) -> *Code_Node, trim := false) -> *T {
	if !node {
		return null;
	}


	callback :: (node: *$T/Code_Node) -> *T #expand {
		print("Visiting node kind: %\n", node.kind);
		return `handler(`userData, node).(*T);
	};

	node = callback(node);

	if #complete node.kind == {
		case .BLOCK;
			block := node.(*Code_Block);
			if !trim {
				block.belongs_to_struct = walkAST(block.belongs_to_struct, callback, true);
			}
			//.parent
			//.owning_statement
			for block.members {
				block.members[it_index] = walkAST(it, callback);
			}
			for block.statements {
				block.statements[it_index] = walkAST(it, callback);
			}

		case .LITERAL;
		case .IDENT;

		case .UNARY_OPERATOR;
			unary := node.(*Code_Unary_Operator);
			unary.subexpression = walkAST(unary.subexpression, callback);

		case .BINARY_OPERATOR;
			bin := node.(*Code_Binary_Operator);
			bin.left = walkAST(bin.left, callback);
			bin.right = walkAST(bin.right, callback);

		case .PROCEDURE_BODY;
			body := node.(*Code_Procedure_Body);
			if !trim {
				body.header = walkAST(body.header, callback, true);
			}
			body.block = walkAST(body.block, callback);

		case .PROCEDURE_CALL;
			call := node.(*Code_Procedure_Call);
			call.procedure_expression = walkAST(call.procedure_expression, callback);
			for call.overloads {
				call.overloads[it_index] = walkAST(it, callback);
			}
			call.resolved_procedure_expression = walkAST(call.resolved_procedure_expression, callback);
			for call.arguments_unsorted {
				call.arguments_unsorted[it_index].expression = walkAST(it.expression, callback);
			}
			call.macro_expansion_block = walkAST(call.macro_expansion_block, callback);
			if call.context_modification {
				for call.context_modification.modification_expressions {
					call.context_modification.modification_expressions[it_index] = walkAST(it, callback);
				}
			}

		case .CONTEXT;

		case .WHILE;
			whileNode := node.(*Code_While);
			whileNode.condition = walkAST(whileNode.condition, callback);
			whileNode.block = walkAST(whileNode.block, callback);

		case .IF;
			ifNode := node.(*Code_If);
			ifNode.condition = walkAST(ifNode.condition, callback);
			ifNode.then_block = walkAST(ifNode.then_block, callback);
			ifNode.else_block = walkAST(ifNode.else_block, callback);
			ifNode.static_if_accepted_case = walkAST(ifNode.static_if_accepted_case, callback);

		case .LOOP_CONTROL;
			loop := node.(*Code_Loop_Control);
			loop.target_ident = walkAST(loop.target_ident, callback);

		case .CASE;
			caseNode := node.(*Code_Case);
			caseNode.condition = walkAST(caseNode.condition, callback);
			caseNode.then_block = walkAST(caseNode.then_block, callback);

		case .RETURN;
			returnNode := node.(*Code_Return);
			for returnNode.arguments_unsorted {
				returnNode.arguments_unsorted[it_index].expression = walkAST(it.expression, callback);
			}

		case .FOR;
			forNode := node.(*Code_For);
			forNode.iteration_expression = walkAST(forNode.iteration_expression, callback);
			forNode.iteration_expression_right = walkAST(forNode.iteration_expression_right, callback);
			forNode.ident_it = walkAST(forNode.ident_it, callback);
			forNode.ident_it_index = walkAST(forNode.ident_it_index, callback);
			forNode.want_replacement_for_expansion = walkAST(forNode.want_replacement_for_expansion, callback);
			forNode.want_pointer_expression = walkAST(forNode.want_pointer_expression, callback);
			forNode.want_reverse_expression = walkAST(forNode.want_reverse_expression, callback);
			forNode.macro_expansion_procedure_call = walkAST(forNode.macro_expansion_procedure_call, callback);
			forNode.block = walkAST(forNode.block, callback);

		case .TYPE_DEFINITION;

		case .TYPE_INSTANTIATION;
			typeInstantiation := node.(*Code_Type_Instantiation);
			typeInstantiation.type_valued_expression = walkAST(typeInstantiation.type_valued_expression, callback);
			typeInstantiation.must_implement = walkAST(typeInstantiation.must_implement, callback);
			typeInstantiation.pointer_to = walkAST(typeInstantiation.pointer_to, callback);
			typeInstantiation.type_directive_target = walkAST(typeInstantiation.type_directive_target, callback);
			typeInstantiation.array_element_type = walkAST(typeInstantiation.array_element_type, callback);
			typeInstantiation.array_dimension = walkAST(typeInstantiation.array_dimension, callback);

		case .ENUM;
			enumNode := node.(*Code_Enum);
			enumNode.internal_type_inst = walkAST(enumNode.internal_type_inst, callback);
			enumNode.block = walkAST(enumNode.block, callback);
			for enumNode.notes {
				enumNode.notes[it_index] = walkAST(it, callback);
			}

		case .PROCEDURE_HEADER;
			header := node.(*Code_Procedure_Header);
			header.constants_block = walkAST(header.constants_block, callback);
			header.arguments = walkAST(header.arguments, callback);
			header.returns = walkAST(header.returns, callback);
			header.parameter_usings = walkAST(header.parameter_usings, callback);
			header.library_identifier = walkAST(header.library_identifier, callback);
			header.polymorph_source_header = walkAST(header.polymorph_source_header, callback);
			header.modify_directives = walkAST(header.modify_directives, callback);
			if !trim {
				header.body_or_null = walkAST(header.body_or_null, callback);
			}
			for header.notes {
				header.notes[it_index] = walkAST(it, callback);
			}

		case .STRUCT;
			structNode := node.(*Code_Struct);
			for structNode.modify_directives {
				structNode.modify_directives[it_index] = walkAST(it, callback);
			}
			for structNode.arguments_block {
				structNode.arguments_block[it_index] = walkAST(it, callback);
			}
			for structNode.constants_block {
				structNode.constants_block[it_index] = walkAST(it, callback);
			}
			structNode.defined_type = walkAST(structNode.defined_type, callback);
			structNode.block = walkAST(structNode.block, callback, true);
			for structNode.notes {
				structNode.notes[it_index] = walkAST(it, callback);
			}

		case .COMMA_SEPARATED_ARGUMENTS;
			commaSeparatedArguments := node.(*Code_Comma_Separated_Arguments);
			for commaSeparatedArguments.arguments {
				commaSeparatedArguments.arguments[it_index] = walkAST(it, callback);
			}

		case .EXTRACT;
			extractNode := node.(*Code_Extract);
			extractNode.from = walkAST(extractNode.from, callback);

		case .DIRECTIVE_BYTES;
			directiveBytesNode := node.(*Code_Directive_Bytes);
			directiveBytesNode.expression = walkAST(directiveBytesNode.expression, callback);

		case .MAKE_VARARGS;
			makeVarargsNode := node.(*Code_Make_Varargs);
			for makeVarargsNode.expressions {
				makeVarargsNode.expressions[it_index] = walkAST(it, callback);
			}

		case .DECLARATION;
			declaration := node.(*Code_Declaration);
			declaration.type_inst = walkAST(declaration.type_inst, callback);
			declaration.expression = walkAST(declaration.expression, callback);
			declaration.alignment_expression = walkAST(declaration.alignment_expression, callback);
			for declaration.notes {
				declaration.notes[it_index] = walkAST(it, callback);
			}

		case .CAST;
			castNode := node.(*Code_Cast);
			castNode.target_type = walkAST(castNode.target_type, callback);
			castNode.expression = walkAST(castNode.expression, callback);

		case .DIRECTIVE_IMPORT;
			import := node.(*Code_Directive_Import);
			import.module_parameters_call = walkAST(import.module_parameters_call, callback);
			import.program_parameters_call = walkAST(import.program_parameters_call, callback);

		case .DIRECTIVE_THIS;

		case .DIRECTIVE_THROUGH;

		case .DIRECTIVE_LOAD;

		case .DIRECTIVE_RUN;
			run := node.(*Code_Directive_Run);
			run.procedure = walkAST(run.procedure, callback);

		case .DIRECTIVE_CODE;
			code := node.(*Code_Directive_Code);
			code.expression = walkAST(code.expression, callback);

		case .DIRECTIVE_POKE_NAME;
			pokeName := node.(*Code_Directive_Poke_Name);
			pokeName.module_struct = walkAST(pokeName.module_struct, callback);

		case .ASM;

		case .DIRECTIVE_BAKE;
			bake := node.(*Code_Directive_Bake);
			bake.procedure_call = walkAST(bake.procedure_call, callback);

		case .DIRECTIVE_MODIFY;
			modify := node.(*Code_Directive_Modify);
			modify.block = walkAST(modify.block, callback);

		case .DIRECTIVE_LIBRARY;

		case .EXPRESSION_QUERY;
			query := node.(*Code_Expression_Query);
			query.expression_to_query = walkAST(query.expression_to_query, callback);

		case .PUSH_CONTEXT;
			pushContext := node.(*Code_Push_Context);
			pushContext.to_push = walkAST(pushContext.to_push, callback);
			pushContext.block = walkAST(pushContext.block, callback);

		case .NOTE;

		case .DIRECTIVE_PLACE;

		case .DIRECTIVE_SCOPE;

		case .TYPE_QUERY;
			typeQuery := node.(*Code_Type_Query);
			typeQuery.type_to_query = walkAST(typeQuery.type_to_query, callback);

		case .DIRECTIVE_LOCATION;
			location := node.(*Code_Directive_Location);
			location.expression = walkAST(location.expression, callback);

		case .DIRECTIVE_MODULE_PARAMETERS;
			params := node.(*Code_Directive_Module_Parameters);
			params.module_parameters = walkAST(params.module_parameters, callback);
			params.program_parameters = walkAST(params.program_parameters, callback);
			params.common_code = walkAST(params.common_code, callback);

		case .DIRECTIVE_ADD_CONTEXT;
			addContext := node.(*Code_Directive_Add_Context);
			addContext.expression = walkAST(addContext.expression, callback);

		case .DIRECTIVE_COMPILE_TIME;

		case .COMPOUND_DECLARATION;
			compound := node.(*Code_Compound_Declaration);
			compound.comma_separated_assignment = walkAST(compound.comma_separated_assignment, callback);
			compound.declaration_properties = walkAST(compound.declaration_properties, callback);
			compound.alignment_expression = walkAST(compound.alignment_expression, callback);
			for compound.notes {
				compound.notes[it_index] = walkAST(it, callback);
			}

		case .DEFER;
			d := node.(*Code_Defer);
			d.block = walkAST(d.block, callback);

		case .USING;
			u := node.(*Code_Using);
			u.expression = walkAST(u.expression, callback);
			u.filter_expression = walkAST(u.filter_expression, callback);

		case .PLACEHOLDER;

		case .DIRECTIVE_INSERT;
			insert := node.(*Code_Directive_Insert);
			insert.expression = walkAST(insert.expression, callback);
			insert.scope_redirection = walkAST(insert.scope_redirection, callback);
			insert.break_replacement = walkAST(insert.break_replacement, callback);
			insert.continue_replacement = walkAST(insert.continue_replacement, callback);
			insert.remove_replacement = walkAST(insert.remove_replacement, callback);
			insert.expansion = walkAST(insert.expansion, callback);

		case .DIRECTIVE_PROCEDURE_NAME;
			directiveProcName := node.(*Code_Directive_Procedure_Name);
			directiveProcName.argument = walkAST(directiveProcName.argument, callback);

		case .DIRECTIVE_WILDCARD;

		case .DIRECTIVE_EXISTS;
			exists := node.(*Code_Directive_Exists);
			exists.query_expression = walkAST(exists.query_expression, callback);
			exists.sync_expression = walkAST(exists.sync_expression, callback);

		case .DIRECTIVE_CONTEXT_TYPE;

		case .RESOLVED_OVERLOAD;
			overload := node.(*Code_Resolved_Overload);
			overload.source_expression = walkAST(overload.source_expression, callback);
			overload.result = walkAST(overload.result, callback);

		case .DIRECTIVE_OVERLAY;
			overlay := node.(*Code_Directive_Overlay);
			overlay.declaration_or_using = walkAST(overlay.declaration_or_using, callback);
			overlay.target_expression = walkAST(overlay.target_expression, callback);
	}

	return node;
}

/*
filterAST :: ($nodeKind: NodeKind, x: *$FilteredNodeType = null) -> $RET
#modify {
	FilteredNodeType = NodeKindToNodeType[xx nodeKind];
	RET = ($startNodes: []*$NodeType, predicate: (node: *FilteredNodeType) -> bool) -> FilterAST(NodeType, FilteredNodeType);
	return FilteredNodeType != void, tprint("filterAST: Invalid node kind %", nodeKind);
} {
	return ($startNodes: []*$NodeType, predicate: (node: *FilteredNodeType) -> bool) -> FilterAST(NodeType, FilteredNodeType).{ startNodes, predicate };
}
*/
//filterAST :: (startNodes: []*$NodeType, FilteredNodeType: Type, predicate: (node: *FilteredNodeType) -> bool) -> FilterAST(NodeType, FilteredNodeType) {
//	return FilterAST(NodeType, FilteredNodeType).{ startNodes, predicate };
//}

//for_expansion :: (filterAST: FilterAST($NodeType, $nodeKind), body: Code, flags: For_Flags) #expand {
//	for *=(flags & .POINTER) <=(flags & .REVERSE) node, index: filterAST.startNodes {
//		if filterAST.predicate(it) {
//			`it = node;
//			`it_index = index;
//			#insert body;
//		}
//	}
//}

/*
filterAST :: (startNodes: []*$NodeType, $nodeKind: NodeKind, predicate: (node: *$FilteredNodeType) -> bool) -> []*FilteredNodeType
#modify {
	FilteredNodeType = NodeKindToNodeType[xx nodeKind];//BUG: can't read this arg's value.  Might need to make filterAST a struct with generic parameters instead of a procedure with generic parameters, and add a for_expansion.
	return FilteredNodeType != void, tprint("filterAST: Invalid node kind %", nodeKind);
} {
	result: [..]FilteredNodeType;
	for startNodes {
		if startNode.kind == nodeKind {
			node := startNode.(*FilteredNodeType);
			if predicate(node) {
				result = array_add(*result, node);
			}
		}
	}
	return result;
}


filterAST :: (startNode: *$NodeType, $nodeKind: NodeKind, predicate: (node: *$FilteredNodeType) -> bool, transform: (node: *FilteredNodeType) -> *$TransformedNodeType) -> NodeType
#modify {
	FilteredNodeType = NodeKindToNodeType[xx nodeKind];
	return FilteredNodeType != void, tprint("filterAST: Invalid node kind %", nodeKind);
} {
	//TODO: walk the expression tree recursively, and for any node that matches nodeKind and predicate, replace it with transform(node).
	return startNode;
}
*/
