
/*
    Procedure Info
    
    Questions to answer:
        What kinds of node nodes will we need to deal with other than identifier?
            Probably #procedure_of_call or #bake_parameters as well...
        When will argument names actually be available, and when will they not?
        Do we really care about return value names?
    
    TODO: 
        create several test cases using different types of procedure expressions
        access through struct members, array indexing, #bake_arguments, #procedure_of_call
            does the struct member case actually matter if the member is nonconstant?
            array case probably does not matter at all, or at least it's not very important
        
        write a procedure to just dump code nodes to the console so that I can see what particular expressions look like as code nodes
    
    NOTE:
        Looking at Code_Procedure_Call, and how #procedure_of_call actually works, it has me wondering:
        Could we use the argument values provided in procedure_of_call as an override on the default values that are provided to Lead Sheets?
        Technically, also, the user could just optionally provide a their own get_default_argument_value for a procedure.
            This is probably the way to go, and we just provide some procedures to create a procedure_info struct in a somewhat pre-checked way
            user can already just bake parameters if they want to, and manually providing default values seems a bit smarter, tbh
    
    TODO: 
        think about what things we could actually do with return value names
        maybe would be useful for something similar to or_return?
        
    TODO: eventually move this to the Reflect module
*/


/*
    This is a helper function to track down a procedure header given some general procedure-typed expression.
    There are probably some edge cases I am missing here so if you pass something that seems like it should work, but it doesn't then let me know. (@u0 on Discord)
*/
get_procedure_header :: (node: *Code_Node) -> *Code_Procedure_Header #compile_time {
    if node == null  return null;
    
    if node.kind == {
      case .PROCEDURE_HEADER;
        return xx node;
        
      case .IDENT;
        ident := node.(*Code_Ident);
        return get_procedure_header(ident.resolved_declaration);
        
      case .DIRECTIVE_BAKE;
        bake := node.(*Code_Directive_Bake);
        return get_procedure_header(bake.procedure_call);
        
      case .TYPE_INSTANTIATION;
        type_inst := node.(*Code_Type_Instantiation);
        if type_inst.type_valued_expression {
            result := get_procedure_header(type_inst.type_valued_expression);
            if result  return result;
        }
        // TODO: other cases?
        
      case .BINARY_OPERATOR;
        binary_operator := node.(*Code_Binary_Operator);
        if binary_operator.operator_type == {
          case #char ".";
            return get_procedure_header(binary_operator.right);
        }
        
      case .DECLARATION;
        declaration := node.(*Code_Declaration);
        if declaration.type_inst {
            result := get_procedure_header(declaration.type_inst);
            if result  return result;
        }
        return get_procedure_header(declaration.expression);
        
      case .DIRECTIVE_INSERT;
        insert := node.(*Code_Directive_Insert);
        return get_procedure_header(insert.expansion);
        
      case .PROCEDURE_CALL;
        call := node.(*Code_Procedure_Call);
        // if (call.flags & .RETURNS_PROCEDURE_POINTER_ONLY)
        // || (call.flags & 0x400) {  // this means procedure_of_call was used
            return get_procedure_header(call.resolved_procedure_expression);
        // }
    }
    
    return null;
}

Procedure_Info :: struct {
    // NOTE: We do this funky overlay thing so that we can return this struct as a constant from a #run, 
    //       but you can still access the type info directly through the using on the type info.
    //       Note also that the member 'type' here refers to the Type_Info_Tag in the using'd type info!
    __type: Type;
    #overlay(__type) using __type_info: *Type_Info_Procedure;
    
    arguments:      [] Argument;
    returns:        [] Argument;
    
    // TODO: Maybe we should have separate arrays for each rather than an array of structs,
    //       main reason being that we already have argument/return types in a separate arrays in __type_info.
    Argument :: struct {
        name:   string;
        flags:  Flags;
        
        Flags :: enum_flags { 
            NONE :: 0; 
            HAS_DEFAULT_VALUE :: 1; 
            IS_VARARGS;
        }
    }
    
    get_default_argument_value: (index: int, provided_storage := null) -> bool, Any;
    
    notes: [] string;
}

/*
    Generates a constant Procedure_Info and returns a pointer to that struct.
    This could certainly use some improvement and return other information about a procedure that would be useful to know at runtime. 
    The implementation here is by no means complete, but 
*/
get_procedure_info :: ($PROCEDURE_EXPRESSION: Code, $SCOPE := #caller_code, $LOC := #caller_location) -> *Procedure_Info #expand {
    PROCEDURE           :: #insert PROCEDURE_EXPRESSION;
    PROCEDURE_TYPE      :: type_of(PROCEDURE);
    PROCEDURE_TYPE_INFO :: type_info(PROCEDURE_TYPE);
    
    // Dumping all the argument types here is necessary for our code generation below.
    ARGUMENT_TYPES :: #run () -> [] Type {
        types := NewArray(PROCEDURE_TYPE_INFO.argument_types.count, Type,, temp);
        for PROCEDURE_TYPE_INFO.argument_types {
            types[it_index] = get_type(it);
        }
        return types;
    }();
    
    /*
        This #run directive does the bulk of the work in this macro. 
        In addition to generating the basic data arrays for arguments, return values, and notes,
        it also generates the Procedure_Info's internal `get_default_argument` procedure.
        
        TODO: I should say some more about this get_default_argument procedure to explain 
              why we need to generate it with code nodes rather than as a string...
    */
    ARGUMENTS, RETURNS, NOTES, GET_DEFAULT_ARGUMENT_CODE :: #run -> [] Procedure_Info.Argument, [] Procedure_Info.Argument, [] string, Code {
        root := compiler_get_nodes(PROCEDURE_EXPRESSION);
        procedure_header := get_procedure_header(root);
        
        if procedure_header == null {
            builder: String_Builder;
            append(*builder, "Unable to resolve procedure header from expression: ");
            Program_Print.print_expression(*builder, root);
            
            error_string := builder_to_string(*builder,, temp);
            compiler_report(error_string, loc = LOC);
        }
        
        if procedure_header.procedure_flags & .POLYMORPHIC {
            compiler_report("Cannot get procedure info for a polymorphic procedure. Try using #procedure_of_call or #bake_arguments to monomorph the procedure before passing it to get_procedure_info.", loc = LOC);
        }
        
        arguments := NewArray(procedure_header.arguments.count, Procedure_Info.Argument,, temp);
        for procedure_header.arguments {
            flags: Procedure_Info.Argument.Flags;
            if it.expression {
                flags |= .HAS_DEFAULT_VALUE;
            }
            if it.type_inst && (it.type_inst.inst_flags & .VARARGS) {
                flags |= .IS_VARARGS;
            }
            arguments[it_index] = .{ it.name, flags };
        }
        
        returns := NewArray(procedure_header.returns.count, Procedure_Info.Argument,, temp);
        for procedure_header.returns {
            returns[it_index] = .{ it.name, .NONE };
        }
        
        notes := NewArray(procedure_header.notes.count, string,, temp);
        for procedure_header.notes {
            notes[it_index] = it.text;
        }
        
        
        get_default_argument_value_procedure_code := ifx 1 {
            push_allocator(temp);
            
            cases: [..] *Code_Case;
            array_reserve(*cases, procedure_header.arguments.count);
            
            // we reuse these nodes for each argument
            ident_ARGUMENT_TYPES := make_ident("ARGUMENT_TYPES");
            
            for procedure_header.arguments {
                if it.expression {
                    code_case := New(Code_Case);
                    code_case.condition = make_integer_literal(it_index);
                    
                    // TODO: This could make for a good test case for the code formatter.
                    //       We will need a new mechanism to insert the integer literal, maybe we add an explicit capture system and that solves our scoping issue as well...
                    
                    then_block_format := #code {
                        ret := New(void, initialized = false);
                        ret.* = #insert,scope(SCOPE) #code 0;
                        return true, ret.*;
                    };
                    code_case.then_block = compiler_get_nodes(then_block_format).(*Code_Block);
                    
                    // replace `void` with actual argument type
                    argument_type_expression := make_binary_operator(.ARRAY_SUBSCRIPT, ident_ARGUMENT_TYPES, make_integer_literal(it_index));
                    code_case.then_block
                        .statements[0].(*Code_Declaration)
                        .expression.(*Code_Procedure_Call)
                        .arguments_unsorted[0].expression = argument_type_expression;
                    
                    // we need to specially replace the #caller_location directive, since it cannot be used as a general expression
                    if it.expression.kind == .DIRECTIVE_LOCATION
                    && it.expression.(*Code_Directive_Location).is_caller_location {
                        code_case.then_block
                            .statements[1].(*Code_Binary_Operator)
                            .right = compiler_get_nodes(#code #location(PROCEDURE_EXPRESSION));
                    } else {
                        // replace `#code 0` in insert with it.expression
                        code_case.then_block
                            .statements[1].(*Code_Binary_Operator)
                            .right.(*Code_Directive_Insert)
                            .expression.(*Code_Directive_Code)
                            .expression = it.expression;
                    }
                    
                    array_add(*cases, code_case);
                }
            }
            
            switch_statement := make_if_case(make_ident("index"), cases);
            default_return_statement := compiler_get_nodes(#code return false, Any.{});
            body_block := make_block(switch_statement, default_return_statement);
            
            // We use the procedure header from the declaration of Procedure_Info.get_default_argument_value so that we don't have to build it manually here.
            // Maybe this is an overly lazy approach, but it's also just kind of cool to show that this can be done.
            exemplar_header := get_procedure_header(
                compiler_get_nodes(code_of(Procedure_Info.get_default_argument_value))
            );
            header := make_procedure_header(exemplar_header.*, body_block);
            
            // And the final result of this massive ifx...
            make_declaration("get_default_argument_value", null, header, .IS_CONSTANT);
        }
        
        // print_code(get_default_argument_value_procedure_code);
        return arguments, returns, notes, compiler_get_code(get_default_argument_value_procedure_code);
    };
    
    #insert GET_DEFAULT_ARGUMENT_CODE;
    
    PROCEDURE_INFO :: Procedure_Info.{
        __type                      = PROCEDURE_TYPE, 
        arguments                   = ARGUMENTS, 
        returns                     = RETURNS, 
        get_default_argument_value  = get_default_argument_value,
        notes                       = NOTES,
    };
    
    return *PROCEDURE_INFO;
}

get_default_argument_value :: (info: Procedure_Info, argument_name: string) -> bool, Any {
    for info.arguments {
        if it.name == argument_name { 
            if !(it.flags & .HAS_DEFAULT_VALUE)  return false, Any.{};
            return true, it.get_default();
        }
    }
    return false, Any.{};
}


#scope_module

#import "Basic";
#import "Compiler";
Program_Print :: #import "Program_Print";


// with_builder :: ($code: Code) -> string {
//     builder: String_Builder;
    
//     // find builder argument and pass this builder, then insert code nodes
//     #insert -> Code {
        
//     }
    
//     return builder_to_string(*builder);
// }

// TODO: move to some compiler utils module, eventually
print_code_nodes :: (builder: *String_Builder, node: *Code_Node, indent := 0) {
    if node == null  return;
    
    put :: (format: string, args: ..Any, newline := true) #expand {
        for 1..indent  append(builder, "  ");
        print(builder, format, ..args);
        if newline  append(builder, "\n");
    }
    
    put("kind: %", node.kind);
    put("type: %", as_type(node.type));
    // put("expression: ", newline = false);
    // Program_Print.print_expression(builder, node);
    // append(builder, "\n");
    
    if node.kind == {
      case .LITERAL;
        literal := node.(*Code_Literal);
        put("value_type: %", literal.value_type);
        // TODO: get_literal_value_as_any, print that here. 
        
      case .IDENT;
        ident := node.(*Code_Ident);
        put("name: %", ident.name);
        put("resolved_declaration: %", ident.resolved_declaration);
        print_code_nodes(builder, ident.resolved_declaration, indent + 1);
        // TODO: maybe we should collect all resolved declarations and display them at the end
        //       could just show the pointer or serial of the resolved declaration here
        
      case .DECLARATION;
        decl := node.(*Code_Declaration);
        print_code_nodes(builder, decl.expression, indent + 1);
        
        // Program_Print.print_expression(builder, decl.expression);
        
      case .DIRECTIVE_INSERT;
        insert := node.(*Code_Directive_Insert);
        print_code_nodes(builder, insert.expansion, indent + 1);
        
      case .UNARY_OPERATOR;
        op := node.(*Code_Unary_Operator);
        str := operator_to_string(xx op.operator_type);
        str = ifx str else string.{ 1, xx *op.operator_type };
        put("operator_type: %", );
        put("subexpression:");
        print_code_nodes(builder, op.subexpression, indent + 1);
        
      case .BINARY_OPERATOR;
        op := node.(*Code_Binary_Operator);
        str := operator_to_string(xx op.operator_type);
        str = ifx str else string.{ 1, xx *op.operator_type };
        put("operator_type: %", str);
        put("left:");
        print_code_nodes(builder, op.left, indent + 1);
        put("right:");
        print_code_nodes(builder, op.right, indent + 1);
        
      case .PROCEDURE_CALL;
        call := node.(*Code_Procedure_Call);
        put("procedure_expression: %", call.procedure_expression);
        print_code_nodes(builder, call.procedure_expression, indent + 1);
        put("resolved_procedure_expression: %", call.resolved_procedure_expression);
        print_code_nodes(builder, call.resolved_procedure_expression, indent + 1);
        // put("overloads:");
        // for overloads.* {
            // print_code_nodes(builder, it, indent + 1);
        // }
        if call.flags {
            put("flags: %", call.flags);
            if call.flags & .INLINE_YES { put("  INLINE_YES"); }
            if call.flags & .INLINE_NO { put("  INLINE_NO"); }
            if call.flags & .RETURNS_PROCEDURE_POINTER_ONLY { put("  RETURNS_PROCEDURE_POINTER_ONLY"); }
            if call.flags & .NO_DEBUG { put("  NO_DEBUG"); }
            if call.flags & .IS_MODULE_PARAMETERS { put("  IS_MODULE_PARAMETERS"); }
        }
        
      case .DIRECTIVE_BAKE;
        bake := node.(*Code_Directive_Bake);
        put("procedure_call:");
        print_code_nodes(builder, bake.procedure_call, indent + 1);
    }
}
