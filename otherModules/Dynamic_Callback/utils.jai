/*
    NOTICE: 
    These are just a bunch of utility things I have copied over from my other various modules to make them available for the purposes of this demo.
    There is probably a lot more here thatn is actually required because I didn't want to spend an hour manually copying every function that I needed.
*/

as_type :: inline (ti: *Type_Info) -> Type { return (*ti).(*Type).*; }

get_variant_base_type :: inline (T: Type) -> Type { return as_type(get_variant_base_type(T.(*Type_Info))); }
get_variant_base_type :: inline (type: *Type_Info) -> *Type_Info {
    while type.type == .VARIANT  type = type.(*Type_Info_Variant).variant_of;
    return type;
}





make_ident :: (name: string, flags: type_of(Code_Ident.flags) = xx 0) -> *Code_Ident {
    ident := New(Code_Ident);
    ident.name = name;
    ident.flags = flags;
    return ident;
}

make_binary_operator :: (operator_type: Operator_Type, lhs: *Code_Node, rhs: *Code_Node, flags: Code_Binary_Operator.Flags = xx 0) -> *Code_Binary_Operator {
    code_operator := New(Code_Binary_Operator);
    code_operator.operator_type = operator_type;
    code_operator.left  = lhs;
    code_operator.right = rhs;
    return code_operator;
}

make_unary_operator :: (operator_type: Operator_Type, expression: *Code_Node) -> *Code_Unary_Operator {
    code_operator := New(Code_Unary_Operator);
    code_operator.operator_type = operator_type;
    code_operator.subexpression = expression;
    return code_operator;
}

make_dot_dereference :: (lhs: *Code_Node, member_name: string) -> *Code_Binary_Operator {
    return make_binary_operator(#char ".", lhs, make_ident(member_name));
}

make_assignment :: (lhs: *Code_Node, rhs: *Code_Node) -> *Code_Binary_Operator {
    return make_binary_operator(#char "=", lhs, rhs);
}


make_procedure_call :: (procedure_name: string, arguments: ..Code_Argument) -> *Code_Procedure_Call {
    call := New(Code_Procedure_Call);
    call.procedure_expression = make_ident(procedure_name);
    call.arguments_unsorted   = array_copy(arguments);
    return call;
}

make_procedure_call :: (procedure_expression: *Code_Node, arguments: ..Code_Argument) -> *Code_Procedure_Call {
    call := New(Code_Procedure_Call);
    call.procedure_expression = procedure_expression;
    call.arguments_unsorted   = array_copy(arguments);
    return call;
}

make_block :: (statements: ..*Code_Node, info := Code_Block.{ block_type = .IMPERATIVE }) -> *Code_Block {
    block := New(Code_Block);
    block.* = info;
    block.statements = array_copy(statements);
    return block;
}


make_declaration :: (name: string, type_inst: *Code_Type_Instantiation = null, expression: *Code_Node = null, flags: type_of(Code_Declaration.flags) = xx 0) -> *Code_Declaration {
    declaration := New(Code_Declaration);
    declaration.name        = name;
    declaration.type_inst   = type_inst;
    declaration.expression  = expression;
    declaration.flags       = flags;
    return declaration;
}

make_declaration :: (name: string, type_name: string, expression: *Code_Node = null, flags: type_of(Code_Declaration.flags) = xx 0) -> *Code_Declaration {
    return make_declaration(name, make_type_inst_from_ident(type_name), expression, flags);
}

make_declaration_from_code :: (name: string, type_inst := #code,null, expression := #code,null, flags: type_of(Code_Declaration.flags) = xx 0) -> *Code_Declaration {
    declaration := New(Code_Declaration);
    declaration.name        = name;
    declaration.type_inst   = ifx type_inst then make_type_inst_from_code(type_inst);
    declaration.expression  = ifx expression then compiler_get_nodes(expression);
    declaration.flags       = flags;
    return declaration;
}


make_type_inst_from_code :: (type_valued_expression: Code) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.type_valued_expression = compiler_get_nodes(type_valued_expression);
    return type_inst;
}

make_type_inst :: (type_valued_expression: *Code_Node) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.type_valued_expression = type_valued_expression;
    return type_inst;
}

make_type_inst_from_ident :: (type_name: string) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.type_valued_expression = make_ident(type_name);
    return type_inst;
}

make_type_inst_fixed_array :: (array_element_type: *Code_Type_Instantiation, array_dimension: int) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.array_element_type = array_element_type;
    type_inst.array_dimension = array_dimension;
    return type_inst;
}

make_type_inst_array_view :: (array_element_type: *Code_Type_Instantiation) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.array_element_type = array_element_type;
    type_inst.inst_flags = .ARRAY_VIEW;
    return type_inst;
}

make_type_inst_resizable_array :: (array_element_type: *Code_Type_Instantiation) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.array_element_type = array_element_type;
    type_inst.inst_flags = .RESIZABLE;
    return type_inst;
}

make_type_inst_pointer_to :: (pointer_to: *Code_Type_Instantiation) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.pointer_to = pointer_to;
    return type_inst;
}

make_cast :: (target_type: *Code_Type_Instantiation, expression: *Code_Node) -> *Code_Cast {
    code_cast := New(Code_Cast);
    code_cast.target_type = target_type;
    code_cast.expression  = expression;
    return code_cast;
}

make_if :: (condition: *Code_Node, then_block: *Code_Block, else_block: *Code_Block, flags: type_of(Code_If.if_flags)) -> *Code_If {
    code := New(Code_If);
    code.condition  = condition;
    code.then_block = then_block;
    code.else_block = else_block;
    code.if_flags   = flags;
    return code;
}

make_if_case :: (condition: *Code_Node, cases: [] *Code_Case) -> *Code_If {
    code_if := New(Code_If);
    code_if.if_flags = .IS_SWITCH_STATEMENT;
    code_if.condition = condition;
    code_if.then_block = ifx 1 {
        block := New(Code_Block);
        block.block_type       = .IMPERATIVE;
        block.owning_statement = code_if;
        block.statements       = cast,force([]*Code_Node) cases;
        for cases {
            // NOTE: I have no idea why, but it seems to be the case that the then blocks of case statements point to the first statement of the then block as their owning statement.
            // it.then_block.owning_statement = it.then_block.statements[0];
            it.then_block.parent = block;
        }
        block;
    };
    return code_if;
}

make_array_literal :: (element_type: *Code_Type_Instantiation, array_members: [] *Code_Node) -> *Code_Literal {
    literal := New(Code_Literal);
    literal.value_type = .ARRAY;
    literal.array_literal_info = New(Code_Array_Literal_Info);
    literal.array_literal_info.element_type  = element_type;
    literal.array_literal_info.array_members = array_members;
    return literal;
}

make_type_of :: (expression: *Code_Node) {
    code_expression_query := New(Code_Expression_Query);
    code_expression_query.query_kind = .TYPE_OF;
    code_expression_query.expression_to_query = expression;
    return code_expression_query;
}

make_float32_literal :: (v: float32) -> *Code_Literal {
    literal := New(Code_Literal);
    literal.value_type    = .NUMBER;
    literal.value_flags   = .IS_A_NUMBER | .FLOAT;
    literal._float64      = v;
    return literal;
}

make_float64_literal :: (v: float64) -> *Code_Literal {
    literal := New(Code_Literal);
    literal.value_type    = .NUMBER;
    literal.value_flags   = .IS_A_NUMBER | .FLOAT | .DEFAULTS_TO_FLOAT64;
    literal._float64      = v;
    return literal;
}

make_return :: (return_values: ..Code_Argument) -> *Code_Return {
    return_statement := New(Code_Return);
    return_statement.arguments_unsorted = return_values;
    return return_statement;
}

make_directive_code :: (expression: *Code_Node) -> *Code_Directive_Code {
    code := New(Code_Directive_Code);
    code.expression = expression;
    return code;
}

make_procedure_header :: (info: Code_Procedure_Header, body_block: *Code_Block = null) -> *Code_Procedure_Header {
    header := New(Code_Procedure_Header);
    header.* = info;
    
    if body_block {
        body := New(Code_Procedure_Body);
        body.header = header;
        body.block  = body_block;
        header.body_or_null = body;
        
        // strip any weird flags that user may have set incorrectly or copied accidentally
        header.procedure_flags &= ~(.TYPE_ONLY);
    }
    
    return header;
}

// maybe this should go in a different module, but this is where it is most useful for now, due to the amount of code node allocations we do.
New :: ($T: Type, $initial: T) -> *T #expand {
    memory := alloc(size_of(T));
    memory.(*T).* = initial;
    return memory.(*T);
}





get_location :: (code: *Code_Node) -> Source_Code_Location {
    return .{
        fully_pathed_filename = ifx code.enclosing_load then code.enclosing_load.fully_pathed_filename,
        line_number = code.l0,
        character_number = code.c0,
    };
}

print_code :: (code: *Code_Node) {
    builder: String_Builder;
    Program_Print.print_expression(*builder, code);
    append(*builder, "\n");
    write_string(builder_to_string(*builder));
}

// NOTE: code nodes will be allocated with context.allocator
make_literal_from_any :: (any: Any) -> *Code_Node {
    base_type := Reflect.get_variant_base_type(any.type);
    
    if base_type.type == {
      case .STRING;
        return make_string_literal(any.value_pointer.(*string).*);
        
      case .BOOL;
        bool_literal := New(Code_Literal);
        bool_literal.value_type = .BOOLEAN;
        bool_literal._u64 = xx any.value_pointer.(*bool).*;
        return bool_literal;
        
      case .INTEGER;
        integer_info := base_type.(*Type_Info_Integer);
        // TODO: I am not sure of the proper way to make a u64 literal as code nodes.
        //       Certainly there must be some way, but at the moment it is not apparent...
        value_as_s64 := get_integer_value_as_s64(integer_info, any.value_pointer);
        return make_integer_literal(value_as_s64);
        
      case .FLOAT;
        float_info := base_type.(*Type_Info_Float);
        if float_info.runtime_size == {
          case 4;
            return make_float32_literal(any.value_pointer.(*float32).*);
          case 8;
            return make_float64_literal(any.value_pointer.(*float64).*);
        }
        assert(false, "unreachable");
        
      case .ENUM;
        enum_info := base_type.(*Type_Info_Enum); 
        value_as_s64 := get_integer_value_as_s64(enum_info.internal_type, any.value_pointer);
        name := Reflect.enum_value_to_name(enum_info, value_as_s64);
        return make_unary_operator(#char ".", make_ident(name));
        
      case .STRUCT;
        struct_info := base_type.(*Type_Info_Struct);
        
        struct_literal := New(Code_Literal);
        struct_literal.value_type = .STRUCT;
        struct_literal.struct_literal_info = New(Code_Struct_Literal_Info);
        using struct_literal.struct_literal_info;
        
        member_count := count_assignable_members(struct_info);
        arguments = NewArray(member_count, *Code_Node);
        
        for struct_info.members {
            if it.flags & (.CONSTANT | .OVERLAY)  continue;
            member_any := Any.{ it.type, any.value_pointer + it.offset_in_bytes };
            arguments[it_index] = make_literal_from_any(member_any);
        }
        
        // type expression will probably not be required in most cases, but we will at least want to be able to pass the type inst as a hint so that we can have a top-level type when it matters
        // TODO: make_type_inst_from_type_info could be useful...
        // struct_literal.struct_literal_info.type_expression = TODO;
        
        return struct_literal;
        
      case .ARRAY;
        array_info := base_type.(*Type_Info_Array);
        array_count, array_data := get_array_count_and_data(array_info, any.value_pointer);
        
        array_literal := New(Code_Literal);
        array_literal.value_type = .ARRAY;
        array_literal.array_literal_info = New(Code_Array_Literal_Info);
        using array_literal.array_literal_info;
        
        array_members = NewArray(array_count, *Code_Node);
        
        for 0..array_count-1 {
            element_any := Any.{ array_info.element_type, array_data + it * array_info.element_type.runtime_size };
            array_members[it] = make_literal_from_any(element_any);
        }
        
        // TODO: support explicit element type
        array_literal_flags = .WAS_UNTYPED;
        
        return array_literal;
        
      case .POINTER;
        // TODO: support optionally copying pointed-at data into constant storage and generating intitializers for that data as well.
        // NOTE: for now, all pointers are just initialized as null pointers
        pointer_literal := New(Code_Literal);
        pointer_literal.value_type = .POINTER;
        pointer_literal.pointer_literal_info = New(Code_Pointer_Literal_Info);
        return pointer_literal;
        
      case .CODE;
        return compiler_get_nodes(#code #code,null);
    }
    
    assert(false, "Unimplemented case in make_literal_from_any.");
    return null;
}


#scope_module 

get_integer_value_as_s64 :: (integer_info: *Type_Info_Integer, value_pointer: *void) -> s64 {
    value_as_s64: s64;
    if integer_info.signed {
        if integer_info.runtime_size == {
          case 1; value_as_s64 = xx value_pointer.(*s\8);
          case 2; value_as_s64 = xx value_pointer.(*s16);
          case 4; value_as_s64 = xx value_pointer.(*s32);
          case 8; value_as_s64 = xx value_pointer.(*s64);
        }
    } else {
        if integer_info.runtime_size == {
          case 1; value_as_s64 = xx value_pointer.(*u\8);
          case 2; value_as_s64 = xx value_pointer.(*u16);
          case 4; value_as_s64 = xx value_pointer.(*u32);
          case 8; value_as_s64 = xx,no_check value_pointer.(*u64);
        }
    }
    return value_as_s64;
}

get_array_count_and_data :: inline (array_info: *Type_Info_Array, value_pointer: *void) -> (int, *void) {
    if array_info.array_type == .FIXED {
        return array_info.array_count, value_pointer;
    } else {
        raw_array := value_pointer.(*Resizable_Array);
        return raw_array.count, raw_array.data;
    }
}

count_assignable_members :: (struct_info: *Type_Info_Struct) -> int {
    count := 0;
    for struct_info.members {
        if it.flags & (.CONSTANT | .OVERLAY)  continue;
        count += 1;
    }
    return count;
}


remove_implicit_return_from_quick_lambda_body_block :: (block: *Code_Block) {
    return_statement := block.statements[block.statements.count-1].(*Code_Return);
    if return_statement.kind == .RETURN {
        return_statement.return_flags &= ~.AUTO_INSERTED_FOR_QUICK_LAMBDA;
    }
}

