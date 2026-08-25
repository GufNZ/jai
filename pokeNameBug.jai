#import "Basic";
#import "Compiler";
#import "Math";

#import,file "2mod.jai"(
	// Toggle this to test single operator/proc vs overloaded operator/proc:
	// Observe that the overloaded proc works either way but the overloaded operator does not work if the OVERLOADED parameter is set to true.
	OVERLOADED = true
);

// Also, the overload-failed-to-match error has the callsite at the end, rather than at the start, so my IDE puts the error in Math.jai::square() rather than here, which is confusing.
// Perhaps it should be "Error while polymorphing here ...callsite... \n Procedure call did not match any of the possible overloads. ..." or something.

main :: () {
	{
		a := X.{ 3 };
		b := X.{ 4 };
		c := a * b;
		d := multiply(a, b);
		print("% * % = %, %\n", a, b, c, d);

		print("square(%) = %\n", a, square(a));
	}

	#if #exists(Y) {
		a := Y.{ 3.0 };
		b := Y.{ 4.0 };
		c := a * b;
		d := multiply(a, b);
		print("% * % = %, %\n", a, b, c, d);

		print("square(%) = %\n", a, square(a));	// Boom!
	}
}

#run {
	set_build_options_dc(.{do_output=false});
	main();
}
