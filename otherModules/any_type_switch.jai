/*
    Type switch macro for Anys
    
    Odin allows users to switch on the type of an Any and automatically casts the any to the specific type desired in each case.
    We can do implement something similar in Jai without too much code, and though the syntax is not quite as nice, 
    it functions about the same, and we can actually pick a different name for the cast variable in each case.
    Each case in the match is given as a struct literal where the first element is the type expression
    and the second element is a quick lambda in which the name for the variable is given as the parameter.
    
    We could remove the need for the struct literal and instead just process the arguments in pairs, 
    but I didn't want to get too crazy for this simple example. We already have enough crazy hacks going on here.
    In the past, many people have requested something like for_expansions, but for if/case.
    With some language support for such a feature, this would almost certainly be much easier and cleaner to implement.
    
    
    
    While I was working on this, I started to think about how far one could push this.
    The most interesting avenue, I think, would be to try and implement some 'polymorphic' cases.
    In theory, If we knew what all the instantiated polymorphs were, then we could generate a unique case for each one.
    But this would almost certainly require a complicated metaprogram and lots of wacky placeholder code.
    
    Or, we could even just do a weaker runtime version of this idea where we extract out any struct parameters and poke those into the lambda body as local variables. 
    Even this second option would probably be pretty useful in many situations.
    If you have any thoughts on any of this, let me know!
*/


#import "Basic";
#import "Compiler";
#import "Code_Format";

main :: () {
    Foo :: struct(T: Type) {
        inner: T;
    }
    
    my_int   := 5;
    my_float := 2.25;
    my_foo   := Foo(u32).{17};
    
    another_int := 3; // So that you can see how scoping works here.
    
    for Any.[ my_int, my_float, "Hello, Sailor", my_foo ] {
        match_any(it,
            int,    i => log("logging an int: %", i.* + another_int),
            float,  f => log("logging a float: %", f.* + 3.5),
            string, s => log("logging a string: %", s.*),
            
            Foo(u32), foo => {
                log("logging a Foo(u32): %", foo.*); 
                foo.inner += 3;
            }
        );
    }
    
    log("logging my_foo: %", my_foo);
}

match_any :: (any: Any, $match_cases: ..Code, $loc := #caller_location, caller_code := #caller_code) #expand {
    #insert,scope(caller_code) -> Code {
        push_allocator(temp);
        auto_release_temp();
        
        caller_nodes := compiler_get_nodes(caller_code).(*Code_Procedure_Call);
        any_expression := caller_nodes.arguments_unsorted[0].expression;
        any_value_pointer_expr := make_dot_dereference(any_expression, "value_pointer");
        
        cases: [..] *Code_Case;
        
        type_expression: *Code_Node;
        
        for match_cases {
            if it_index & 1 == 0 {
                type_expression = compiler_get_nodes(it);
                continue;
            }
            
            header := compiler_get_nodes(it).(*Code_Procedure_Header);
            if !(header.kind == .PROCEDURE_HEADER && (header.procedure_flags & .QUICK == .QUICK)) {
                compiler_report("Expected a quick lambda expression for match case.", loc = get_location(header));
            }
            if (header.arguments.count != 1) {
                compiler_report("Quick lambda expression used as a match case must only accept one argument, representing the identifier of the cast value.", loc = get_location(header));
            }
            
            assert(header.body_or_null != null);
            body_statements := header.body_or_null.block.statements;
            
            cast_decl_name := header.arguments[0].(*Code_Declaration).name;
            
            code_case := New(Code_Case);
            code_case.condition = type_expression;
            code_case.then_block = ifx 1 {
                block := New(Code_Block);
                block.block_type = .IMPERATIVE;
                block.owning_statement = code_case;
                
                type_inst  := make_type_inst(make_unary_operator(#char "*", type_expression));
                cast_expr  := make_cast(type_inst, any_value_pointer_expr);
                local_decl := make_declaration(cast_decl_name, expression = cast_expr);
                
                block.statements = NewArray(body_statements.count + 1, *Code_Node);
                for body_statements  block.statements[it_index + 1] = it;
                block.statements[0] = local_decl;
                
                // remove the implicit return statement that gets inserted in quick lambdas
                return_statement := block.statements[block.statements.count-1].(*Code_Return);
                if return_statement.kind == .RETURN {
                    assert(return_statement.arguments_unsorted.count == 1);
                    block.statements[block.statements.count-1] = return_statement.arguments_unsorted[0].expression;
                }
                
                block;
            };
            
            array_add(*cases, code_case);
        }
        
        if_cond := make_unary_operator(.POSTFIX_DEREFERENCE,
            make_cast(
                make_type_inst(
                    make_unary_operator(#char "*", make_ident("Type"))
                ),
                make_unary_operator(#char "*", 
                    make_dot_dereference(any_expression, "type")
                )
            )
        );
        if_cond.subexpression.node_flags |= .IS_PARENTHESIZED;
        
        code_if := make_if_case(if_cond, cases);
        
        // uncomment this to see what the generated code would look like
        #import "Program_Print";
        sb: String_Builder;
        print_expression(*sb, code_if);
        write_string("----------------------------\n");
        write_string(builder_to_string(*sb));
        write_string("\n");
        
        return compiler_get_code(code_if);
    }
}
