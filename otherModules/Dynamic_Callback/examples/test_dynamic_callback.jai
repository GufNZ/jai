#import "Basic"()(MEMORY_DEBUGGER=true);
#import,file "../module.jai";


/*
    This file has a couple of basic tests in it, but it's not exactly the best demo of the module's functionality.
    
    But in essence, there's really only one main call required to set up the callback object, and that's make_dynamic_callback.
    You just write the procedure call with all its arguments directly inside the call to make_dynamic_callback, and optionally also pass an allocator to use for the returned callback object.
    
    You can then invoke the callback object as many times as you want with call(), and when you're done you just free the callback object.
    Since all of the required data is allocated together, you don't have to worry about freeing any other associated data separately.
    
    Some nice features that are supported:
        1. You an pretty much pass any arbitrarily complex expressions in the arguments for the callback, and it will just work.
           This was a pain to implement due to various code generation things, specifically with respect to how scoping works on inserted nodes.
           There could probably be some compiler support that would make this sort of thing much easier and cleaner, and I have some ideas about what that could look like.
        2. Varargs function as one would expect and the values get captured by value.
           For `..Any` varargs, the user has the option of copying the values pointed to by the Anys as well. This is enabled by default.
        3. Structs and fixed arrays are also captured by value when passed "by value".
        4. Default parameters that reference the context work. (They take the value at the time of the call to make_dynamic_callback).
    
    Currently, the biggest limitations of this module are as follows:
        1. You can't yet pass additional parameters when you call() the callback, nor can you substitute/override the parameter values that were already provided in make_dynamic_callback.
           This is not because this is not possible with the existing design, but just because I haven't implemented that functionality yet.
           I have a plan to make this very ergonomic though, and I'm excited to issue an update when I get around to trying it out.
        2. Context modifications on the call given make_dynamic_callback don't do anything.
           This may change later if I can figure out a decent way represent context modifications structurally.
        3. Other semantics around context are arguably a bit awkward. 
           Default parameters that reference the context take the value at the time of the call to make_dynamic_callback, but any references to the context inside the procedure body will of course get the actual current context.
           (I don't think there's any feasible way we could save a snapshot of the context at the time the callback is created, and this is probably th ebehaviour you want anyway, but it should be noted.)
        4. Getting return values as an `[] Any` is not ideal, since it requires manual user unpacking and typechecking.
           Perhaps by using some polymorphic Dynamic_Callback struct, we can make a nicer interface. 
        5. There's really no generalized capture mechanism like with traditional closures, only capture via argument passing.
           Implementing capture will require some more work, and I'll have to workshop the syntax to find something ergonmomic and intutive.
*/

main :: () {
    defer report_memory_leaks();
    
    call_and_report :: (callback: Dynamic_Callback) {
        log("\nCalling dynamic callback:", );
        ok, results := call(callback);
        if ok  log("Results: %", results);
        else   log("Error: failed to execute dynamic callback.");
    }
    
    sum :: (values: ..$T) -> T {
        sum: T = 0;
        for values  sum += it;
        return sum;
    }
    
    Foo :: struct {
        number: int;
    }
    
    log_foo :: (foo := Foo.{ 3 }) {
        log("foo is %", foo);
    }
    
    make_foo :: (number: int) -> Foo {
        return .{ number };
    }
    
    // TEST: referencing a local variable, default value with locally-declared struct type
    {
        foo := Foo.{ 5 };
        callback := make_dynamic_callback( log_foo(foo) );
        defer free(callback);
        call_and_report(callback);
    }
    
    // TEST: default value with locally-declared struct type
    {
        callback := make_dynamic_callback( log_foo() );
        defer free(callback);
        call_and_report(callback);
    }
    
    // TEST: polymorphic varargs, referencing a local variable
    {
        number := 5;
        callback := make_dynamic_callback( sum(1, 2, 3, 4, number) );
        defer free(callback);
        call_and_report(callback);
    }
    
    // Context Dereferences
    {
        context.my_favorite_number = 7;
        
        // Parameters whose default values reference the context will be computed based on the value of the context member at the time when the callback object is created.
        log_my_favorite_number :: (number := context.my_favorite_number) {
            print("My favorite number was %, but now it is %.\n", number, context.my_favorite_number);
        }
        
        // Although we modify context.my_favorite_number before calling the callback, the value for the `name` parameter has already been computed.
        // Because of this, we will see two different values for context.my_favorite_number.
        
        // Case 1: passing context.my_favorite_number explicitly
        {
            callback := make_dynamic_callback( log_my_favorite_number(context.my_favorite_number) );
            defer free(callback);
            call_and_report(callback,, my_favorite_number = 69);
        }
        
        // Case 2: using the default value for the `name` parameter
        {
            callback := make_dynamic_callback( log_my_favorite_number() );
            defer free(callback);
            call_and_report(callback,, my_favorite_number = 420);
        }
        
        // Case 3: modifying the context in the call to make_dynamic_callback
        //         Unlike the two above case, this will change the value computed for the parameter value.
        {
            callback := make_dynamic_callback( log_my_favorite_number(),, my_favorite_number = 58008 );
            defer free(callback);
            call_and_report(callback,, my_favorite_number = 0xcafe_babe);
        }
        
        // TODO: This case results in an 'undeclared identifier' error at the moment... Not sure why!
        // Case 4: modifying the context in the call *provided to* make_dynamic_callback
        #if false {
            callback := make_dynamic_callback( log_my_favorite_number(,, my_favorite_number = 35) );
            defer free(callback);
            call_and_report(callback,, my_favorite_number = 35);
        }
    }
    
    // NOTE: If you manually spread a [] Any into Any varargs, the values of the Anys will not be copied, only the array view itself.
    //       This is done so that you can express these specific semantics if you so choose, and because it is also simpler for make_dynamic_callback to ignore this complex case.
    // args := Any.[ 1, context.my_favorite_number, 3 ];
}

#add_context my_favorite_number: int;
