/*

  Here we show how to make simple Tagged_Union support, which is something that people request sometimes.
  This language, like C, has a built-in union type, designated by the keyword 'union'. But, when using
  a union, you have to know which type is stored inside it, so that you know how to interpret the memory
  stored in the union. Usually this is done using some kind of enum-based type tag. But in a C-like
  language, maybe it's a hassle to define all these type tags and remember what the tags are called,
  and so forth. So here we define a tagged union that takes care of the tag automatically.

  To use this, you can say something like:

      u: Tagged_Union(int, float, Vector3, [10] u16);

  (See the example in the comment at the bottom of the file). 
  Tagged_Union will compute how much space it needs to store the biggest of these types. Then when you call

      set(*u, 42.5);

  it will set the tag to 'float' (which is the type of the value on the right), and put the 42.5 into
  the value memory. You can call 'isa' to ask whether the stored value is of the appropriate type.

  Because this language is not really about overloading weird operators, and is definitely not about overloading
  the = or == operators, we do not attempt to do these things here. We do not want to pretend Tagged_Union
  is a primitive type.

  @Incomplete: We haven't yet done some kind of macro for switching on the type. I expect this to be an 
  interesting test of the macro system that will motivate a bit of improvement.  -jblow, 21 April 2021.

*/

#module_parameters (DEBUG := false);  // Enable DEBUG for extra checking.


Tagged_Union :: struct (value_types: .. Type) {
    tag: Type;                // 'tag' tells us what the type is of the value contained in 'bytes' below.
                              // It must be set to some value in 'value_types'.
    
    bytes: [NUM_VALUE_BYTES] u8;
    
    NUM_VALUE_BYTES : s64 : #run get_biggest_size(value_types);
    // I suppose it would be more debugger-friendly to make this an actual union,
    // not just some bytes?
}

// set(*u, value): Set the type tag of 'u' to type_of(value), and copy 'value' into u's storage.
set :: (using u: *Tagged_Union, value: $T) {

    #if DEBUG == true {
        // If DEBUG is enabled, check that T is one of the types that 'u' can store. Note that this check will happen
        // at compile-time, due to the #run.
        #run {
            found := false;
            for value_types  if it == T { found = true; break; }

            assert(found);
        }
    }

    tag = T;
    pointer := cast(*T) bytes.data;
    pointer.* = value;
}

// isa(u, T): Does the tagged union 'u' hold a value of type 'T'?
isa :: (using u: Tagged_Union, $T: Type) -> *T {
    // If the tag is T, return appropriately casted memory.
    // Otherwise, return null.
    // This is equivalent to true or false if used in an 'if' statement.
    if tag == T  return cast(*T) bytes.data;
    return null;
}


#scope_file

#import "Basic"; 

// get_biggest_size is used at compile-time by the #run in Tagged_Union.
get_biggest_size :: (types: [] Type) -> s64 {
    biggest: s64;

    // This cast to *Type_Info requires runtime_storageless_type_info to be disabled,
    // or for us to be running at compile-time. We know for sure in this case that we are
    // calling this routine at compile-time, but in runtime use, this kind of cast
    // presumes that Type_Info has been exported for all runtime types.
    for types  biggest = max(biggest, (cast(*Type_Info)(it)).runtime_size); 

    return biggest;
}


/*

Example program:

#import "Tagged_Union"(DEBUG=true);

main :: () {
    // @Incomplete: make sure this typecheck works!
//    a: Tagged_Union(Type.[float, float64, Vector2, Vector3, Quaternion]);
    a: Tagged_Union(float, float64, Vector2, Vector3, Quaternion);

    set(*a, 5.0);
    print("a is: %\n", a);

    set(*a, cast(float64) 42.42);
    print("a is: %\n", a);

    q := Quaternion.{x=1, w=1};

    set(*a, q);

    print("a is: %\n", a);

    quat := isa(a, Quaternion);
    if quat {
        print("a as Quaternion is %\n", quat.*);
    }

    // If you uncomment the below call to 'set', it will cause a compile-time assertion failure,
    // since u8 is not one of the types in the tagged union.
    // set(*a, cast(u8) 24);
}

#import "Basic";
#import "Math";
*/
