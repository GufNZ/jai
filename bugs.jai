main :: () {
	print(">%\n", root("42", ExpHolder(2).{}));
}
#run main();

#import "Basic";
ExpHolder :: struct(exp: int) { EXP :: exp; }

root :: (x: int, e: ExpHolder($EXP)) -> int {
	print("root: exp = %\n", EXP);
	return x * EXP;
}
root :: (s: string, e: ExpHolder($EXP)) -> $RET
#modify {
	print("root: exp = %\n", EXP);

	//BUG: this one gets Error: Type mismatch. Type wanted: s64; type given: Type.
	//print("<%\n", root(42, ExpHolder(EXP).{}));

	//BUG: this one just segfaults the compiler..!
	print("<%\n", root(42, ExpHolder(9/*EXP*/).{}));

	RET = int;

	return true;
} {
	result : RET;
	result.amount = xx root(s.count, 1.0 / EXP);
	return result;
}
