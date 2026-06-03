test :: (userData: $D, x: *$T/Code_Node) -> *T {
	handler := (userData: D, node: *Code_Node) -> *Code_Node {
		print("handling (%): %\n", userData, node.kind);
		return node;
	};

	callback :: (node: *$T/Code_Node) -> *T #expand {
		print("Visiting node kind: %\n", node.kind);
		return `handler(`userData, node).(*T);
	};

	return callback(x);
}
main :: () {
	y:=1.1.;
	set_build_options_dc(.{do_output = false, interactive_bytecode_debugger = true});
	x := compiler_get_nodes(1 + 3).(*Code_Binary_Operator);

	print("type: %\n", type_of(x));
	print("Result: %\n", test(42, x).*);
}

#run main();

#import "Basic";
#import "Compiler";
