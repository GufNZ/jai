#module_parameters (OVERLOADED := true);

X :: struct {
	v: int;
}
#if OVERLOADED {
	Y :: struct {
		v: float;
	}
}

operator* :: (a: X, b: X) -> X {
	return X.{ a.v * b.v };
}

multiply :: (a: X, b: X) -> X {
	return X.{ a.v * b.v };
}

#if OVERLOADED {
	operator* :: (a: Y, b: Y) -> Y {
		return Y.{ a.v * b.v };
	}

	multiply :: (a: Y, b: Y) -> Y {
		return Y.{ a.v * b.v };
	}
}

#scope_file
M :: #import "Math";
#poke_name M operator*;
// I am not allowed to use #procedure_of_call here either it seems...:
//#poke_name M #procedure_of_call operator*(X.{}, X.{});
//#poke_name M #procedure_of_call operator*(Y.{}, Y.{});
#poke_name M multiply;
