#import "Basic";

Closure :: #import,file "../module.jai";

main :: () {
    say_hello :: (name : string) {
        print("Hello %!\n", name);
    }

    say_multiple_hello :: (name : string, count : int) {
        for 1..count print("Hello %!\n", name);
    }

    // Basic usage
    {
        my_closure_with_0_args : Closure.Closure;
        my_closure_with_1_args : Closure.Closure;
        my_closure_with_2_args : Closure.Closure;

        {
            name := "Harry";

            Closure.init(*my_closure_with_0_args, () { print("Hello World !\n"); });
            Closure.init(*my_closure_with_1_args, say_hello, name);

            name = "Sally";

            Closure.init(*my_closure_with_2_args, say_multiple_hello, name, 3);
        }

        Closure.call(*my_closure_with_2_args);
        Closure.call(*my_closure_with_1_args);
        Closure.call(*my_closure_with_0_args);
    }

    // Compile time error if incorrect arguments provided to the callback
    #if false {
        my_closure : Closure.Closure;

        // Incorrect number of arguments
        Closure.init(*my_closure, say_hello, "Sailor", "Other");

        // Incorrect types
        Closure.init(*my_closure, say_hello, 1664);
    }
}