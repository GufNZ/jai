#import "Basic";
#import "Compiler";
#import "Program_Print";
// #import "Code_Format";

global := 3;

main :: () {
    CONSTANT :: 5;
    
    Foo :: struct { i: int; }
    foo := Foo.{ 5 };
    
    // NOTE: We can access constants and globals from the caller's scope without needing to explicitly capture.
    parallel_for(3, #code {
        foo.i += CONSTANT - global;
    }, .[ *foo ]);
    
    log("foo is %", foo);
}


// NOTE: This is a new trick I just discovered while working on this!
// We can smuggle Code constants from the macro's scope back into the caller's scope and use them there.
// This allows us to do something like the following, where we insert code with the caller's scope that in turn inserts more code which was passed to this macro.

// There are 3 scopes we have to think about: the caller, parallel_for, and task.
// When we write a #run or #insert in a macro like parallel_for, we are executing that #run within the macro's scope.
// But in many cases, we also want the #run to have access to things in the caller's scope.
// In order to be able to access both scopes, we can do an insert,scope(#caller_code) in which we include 2 things: constant declarations that duplicate constants from the macro's scope, and another inserter that runs in that target scope.


parallel_for :: (count: Code, $body: Code, $CAPTURES: [$N] Code, $force_single_threaded := false) #expand {
    // This outer insert is done as code so that we can accurately and efficiently marshall the constants from this macro's (parameter) scope into the caller's scope.
    #insert,scope(body) -> Code {
        // TODO: We should probably validate that count root type is integer.
        count_decl    := make_declaration("count", expression = compiler_get_nodes(count));
        body_decl     := make_code_constant_declaration("body", compiler_get_nodes(body));
        captures_decl := make_code_array_constant_declaration("CAPTURES", CAPTURES);
        
        // After the outer code insert occurs, this inner string insert will run and insert the generated Capture struct.
        // This could all be done as code nodes as well, but it's bit easier to do as a string and we get the beneift of the result of this step being added to the added_strings file for this workspace.
        string_inserter := compiler_get_nodes(#code #insert -> string {
            // Gather the identifiers for all of the capture expressions.
            // For now, we will assert that all the captures are simple identifiers (or pointers to simple identifiers) and not more complex expressions.
            // Although I am collecting the code nodes here as well, we don't actually need them in this simplified example, only the names.
            // Perhaps you would want the nodes as well if we were allowing more complex capture expressions.
            captures: [CAPTURES.count] struct { name: string; node: *Code_Node; };
            for code, index: CAPTURES {
                node := compiler_get_nodes(code);
                
                name: string;
                if node.kind == {
                  case .IDENT;
                    name = node.(*Code_Ident).name;
                    
                  case .UNARY_OPERATOR;
                    op := node.(*Code_Unary_Operator);
                    if op.subexpression.kind != .IDENT {
                        compiler_report("Capture expression must be an identifier or pointer to identifier.", loc = get_location(node));
                    }
                    name = op.subexpression.(*Code_Ident).name;
                    
                  case;
                    compiler_report("Capture expression must be an identifier or pointer to identifier.", loc = get_location(node));
                }
                
                // Verify that capture was not repeated.
                for prev_index: 0..index-1 {
                    prev := captures[prev_index];
                    if name == prev.name {
                        compiler_report("Duplicate captures are not permitted.", loc = get_location(node));
                    }
                }
                
                captures[index] = .{ name, node };
            }
            
            builder: String_Builder;
            
            append(*builder, "Capture :: struct #type_info_none {\n");
            for capture, index: captures {
                print(*builder, "    %: type_of(#insert CAPTURES[%]);\n", capture.name, index);
            }
            append(*builder, "}\n");
            
            append(*builder, "capture: Capture = ---;\n");
            for capture, index: captures {
                print(*builder, "capture.% = #insert CAPTURES[%];\n", capture.name, index);
            }
            
            
            // NOTE: We can't just use a single task procedure with a Code value bake because we need the inserted code to have access to both the local procedure scope of task, but also to the caller's scope.
            // The only way to do this is to make sure that the entirety of the task proc is inserted in the caller's scope, and the inner code is inserted in the proc scope.
            // Also, since we are already generating this procedure uniquely for each call to parallel_for, we can just use *Capture for the first parameter's type rather than using *void.
            append(*builder, #string JAI
task :: (using capture: *Capture, start: s64, block_count: s64) {
    end := start + block_count;
    for it: start..end-1 {
        // NOTE: without insert,scope() here, we would not be able to access 'it' from inside 'body'.
        #insert,scope() body;
    }
}

// NOTE: For this example I am just calling the task proc directly.
task(*capture, 0, count);
            JAI);
            
            return builder_to_string(*builder);
        });
        
        block := make_block(count_decl, body_decl, captures_decl, string_inserter);
        
        // Uncomment this to see what the generated code looks like before it is inserted.
        // sb: String_Builder;
        // print_expression(*sb, block);
        // write_string("----------------------------\n");
        // write_string(builder_to_string(*sb));
        // write_string("\n");
        
        return compiler_get_code(block);
    }
}

/*
    Below are a bunch of helper functions from my Code_Format module. 
    I've copied over only the ones I needed for this example, but there are many more where these came from!
*/

make_code_constant_declaration :: (name: string, code: Code) -> *Code_Declaration {
    return make_code_constant_declaration(name, compiler_get_nodes(code));
}

make_code_constant_declaration :: (name: string, node: *Code_Node) -> *Code_Declaration {
    code_directive_code := New(Code_Directive_Code);
    code_directive_code.expression = node;
    return make_declaration(name, null, code_directive_code, flags = .IS_CONSTANT);
}

make_code_array_constant_declaration :: (name: string, codes: [] Code) -> *Code_Declaration {
    nodes := NewArray(codes.count, *Code_Node);
    for code, index: codes {
        code_directive_code := New(Code_Directive_Code);
        code_directive_code.expression = compiler_get_nodes(code);
        nodes[index] = code_directive_code;
    }
    code_type_inst := make_type_inst_from_ident("Code");
    array_literal := make_array_literal(code_type_inst, nodes);
    return make_declaration(name, null, array_literal, flags = .IS_CONSTANT);
}

make_declaration :: (name: string, type_inst: *Code_Type_Instantiation = null, expression: *Code_Node = null, flags: type_of(Code_Declaration.flags) = xx 0) -> *Code_Declaration {
    declaration := New(Code_Declaration);
    declaration.name        = name;
    declaration.type_inst   = type_inst;
    declaration.expression  = expression;
    declaration.flags       = flags;
    return declaration;
}

make_type_inst_from_ident :: (type_name: string) -> *Code_Type_Instantiation {
    type_inst := New(Code_Type_Instantiation);
    type_inst.type_valued_expression = make_ident(type_name);
    return type_inst;
}

make_array_literal :: (element_type: *Code_Type_Instantiation, array_members: [] *Code_Node) -> *Code_Literal {
    literal := New(Code_Literal);
    literal.value_type = .ARRAY;
    literal.array_literal_info = New(Code_Array_Literal_Info);
    literal.array_literal_info.element_type  = element_type;
    literal.array_literal_info.array_members = array_members;
    return literal;
}

make_ident :: (name: string, flags: type_of(Code_Ident.flags) = xx 0) -> *Code_Ident {
    ident := New(Code_Ident);
    ident.name = name;
    ident.flags = flags;
    return ident;
}

make_block :: (statements: ..*Code_Node, info := Code_Block.{ block_type = .IMPERATIVE }) -> *Code_Block {
    block := New(Code_Block);
    block.* = info;
    block.statements = array_copy(statements);
    return block;
}

get_location :: (code: *Code_Node) -> Source_Code_Location {
    return .{
        fully_pathed_filename = ifx code.enclosing_load then code.enclosing_load.fully_pathed_filename,
        line_number = code.l0,
        character_number = code.c0,
    };
}
