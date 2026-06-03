#module_parameters ()(AMERICAN_SPELLING := false, UNTYPED_ADD_SUBTRACT := false);

#if AMERICAN_SPELLING {
	Meter :: Metre;
	Meters :: Metres;
	meter :: metre;
	meters :: metres;
}

//dump :: (s: $T, loc := #caller_location) -> T {
//	print("\e[92mDump at %:%:%\e[0m\n", loc.fully_pathed_filename, loc.line_number, loc.character_number);
//	print("\e[93m%\e[0m\n\n", replace(s, "\%", "\\%"));
//	return s;
//}

gcd :: (a: int, b: int) -> int {
	while b {
		a, b = b, a % b;
	}

	return a;
}

#scope_file

lowerInitial :: (s: string) -> string {
	if s.count == 0 {
		return s;
	}

	t := copy_string(s,, temp);
	t[0] |= 32 .(u8);
	return t;
}

fieldsTemplate :: (template: string, joiner := "", alt: (name: string) -> string = null, prefix := "", suffix := "", loc := #caller_location, halt := false) -> string {
	sb: String_Builder;

	if halt  debug_break();

	if prefix {
		print(*sb, prefix);
	}

	for enum_names(SIUnit) {
		// Skip NONE:
		if !it_index  continue;


		if it_index > 1 {
			print(*sb, joiner);
		}

		if alt {
			print(*sb, template, it, alt(it), loc=loc);
		} else {
			print(*sb, template, it, loc=loc);
		}
	}

	if suffix {
		print(*sb, suffix, loc=loc);
	}

	return builder_to_string(*sb);
}

join :: (things: ..() -> string) -> string {
	sb: String_Builder;
	for things {
		append(*sb, it());
	}

	return builder_to_string(*sb);
}

#scope_export

SIUnit :: enum {
	NONE;
	Metre;
	Kilogram;
	Second;
	Ampere;
	Kelvin;
	Mole;
	Candela;
}

#insert #run join(
	() => #string JA
SIQuantity :: struct(
	DataType: Type,

JA,
	() => fieldsTemplate("\t%Num: int, %1Denom: int, %1Exp: int", ",\n"),
	() => #string JA

)
{
	amount : DataType;
}

SIQuantityTypeParams :: struct {
	#insert #run,stallable -> string {
		sb: String_Builder;

JA,
	() => fieldsTemplate("0,0,0", ",", prefix="\t\tti := type_info(SIQuantity(int,", suffix="));\n"),
	() => #string JA
		for ti.specified_parameters {
			print(*sb, "\t%: %;\t// @ %\n", it.name, get_type(it.type), it.offset_into_constant_storage);
		}

		print(*sb, "\n\tlastSet: SIUnit;\n");

		return builder_to_string(*sb);
	};

	validationError: string = "";
}

getSIParameters :: (t: Type) -> SIQuantityTypeParams {
	ti := t.(*Type_Info_Struct);
	tp := type_info(SIQuantityTypeParams);

	p: SIQuantityTypeParams;

	q := (*p).(*u64);
	s := ti.constant_storage.data.(*u64);

	for param: ti.specified_parameters {
		for tp.members {
			if it.name == param.name/* && it.type == param.type*/ {
				q[it.offset_in_bytes >> 3] = s[param.offset_into_constant_storage >> 3];
				break;
			}
		}
	}

	return p;
}

SI :: (parameters: SIQuantityTypeParams) -> string #expand #compile_time {
JA,
	() => fieldsTemplate(
		"\t%Num=parameters.%1Num, %1Denom=parameters.%1Denom, %1Exp=parameters.%1Exp",
		",\n",
		prefix="return #string JAI\n#bake_arguments SIQuantity(\n",
		suffix="\n);\nJAI;"
	),
	() => #string JA
}

#scope_file

normalise :: (pp: SIQuantityTypeParams) -> SIQuantityTypeParams {
	p := pp;
	d: int = ---;
JA,
	() => fieldsTemplate(
		#string JA
	if p.%Num && p.%1Denom {
		d = gcd(p.%1Num, p.%1Denom);
		p.%1Num /= d;
		p.%1Denom /= d;
	}
JA,
		"\n"
	),
	() => #string JA

	return p;
}

#scope_export

JA,
	() => fieldsTemplate(
		#string JA
%2 :: inline (mod: (q: SIQuantityTypeParams) -> SIQuantityTypeParams, p: SIQuantityTypeParams = .{}) -> SIQuantityTypeParams {
	return %2(p, mod);
}
%2 :: (pp := SIQuantityTypeParams.{}, mod: (q: SIQuantityTypeParams) -> SIQuantityTypeParams = null) -> SIQuantityTypeParams {
	p := pp;

	p.%1Num = 1;
	p.%1Denom = 1;
	p.%1Exp = 1;

	p.lastSet = .%1;

	if mod {
		p = mod(p);
	}

	return normalise(p);
}
%2s :: %2;
JA,
		"\n",
		name => lowerInitial(name)
	),
	() => #string JA

#scope_file

mult :: (pp: SIQuantityTypeParams, n: u64, name: string) -> SIQuantityTypeParams {
	p := pp;

	if p.lastSet == {
JA,
	() => fieldsTemplate(
		#string JA
		case .%;
			p.%1Num *= n;
JA
	),
	() => #string JA
		case;
			assert(false, "Can only apply % to a base SI unit.", name);
	}

	return p;
}

div :: (pp: SIQuantityTypeParams, n: u64, name: string) -> SIQuantityTypeParams {
	p := pp;

	if p.lastSet == {
JA,
	() => fieldsTemplate(
		#string JA
		case .%;
			p.%1Denom *= n;
JA
	),
	() => #string JA
		case;
			assert(false, "Can only apply % to a base SI unit.", name);
	}

	return p;
}

JA,
	() -> string {
		big		:: string.["kilo",	"mega",	"giga",	"tera",	"peta",	"exa",	/* Too big for int: "zetta", "yotta"*/];
		small	:: string.["milli",	"micro","nano",	"pico",	"femto","atto",	/* Too big for int: "zepto", "yocto"*/];

		//bigBinary :: string.["kibi", "mebi", "gibi", "tebi", "pebi", "exbi", /* Too big for int: "zebi", "yobi"*/];

		common :: (n: u64, it: string, proc: string) -> string {
			return tprint(
				#string JA
 % :: (p: SIQuantityTypeParams) -> SIQuantityTypeParams {
	return %(p, %, "%1");
}

JA,
				it,
				proc,
				n
			);
		}

		sb: String_Builder;
		n: u64 = 1;
		for big {
			n *= 1000;
			append(*sb, common(n, it, "mult"));
		}

		print(*sb, "\n");

		n = 1;
		for small {
			n *= 1000;
			append(*sb, common(n, it, "div"));
		}

		return builder_to_string(*sb);
	},
	() => #string JA

per :: (pp: SIQuantityTypeParams) -> SIQuantityTypeParams {
	p := pp;

	if p.lastSet == {
JA,
	() => fieldsTemplate(
		#string JA
		case .%;
			p.%1Exp = -p.%1Exp;
JA
	),
	() => #string JA

		case;
			assert(false, "Can only apply per to a base SI unit.");
	}

	return p;
}

#scope_file

JA,
	() => fieldsTemplate(
		#string Ja
% :: #insert #run,stallable SI(%());
Ja,
		"\n",
		name => lowerInitial(name)
	),
	() => #string JA

modCheck :: (ok: bool, errorMessage: string, args: ..Any) -> bool #expand {
	if !ok {
		`return false, tprint(errorMessage, ..args);
	}
};
modCheck :: (p: *SIQuantityTypeParams, ok: bool, errorMessage: string, args: ..Any) -> SIQuantityTypeParams #expand {
	if !ok {
		p.validationError = tprint(errorMessage, ..args);
		return p.*;
	}
};

dataTypesMatch :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	return a.DataType == b.DataType;
}

ratiosCompatible :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	ok := true;
JA,
	() => fieldsTemplate("\tok &&= a.%Num == b.%1Num && a.%1Denom == b.%1Denom || !a.%1Num || !b.%1Num;", "\n"),
	() => #string JA
	return ok;
}

ratiosEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
JA,
	() => fieldsTemplate("a.%Num == b.%1Num && a.%1Denom == b.%1Denom", "\n\t\t&& ", prefix="return ", suffix=";"),
	() => #string JA
}

exponentsEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
JA,
	() => fieldsTemplate("a.%Exp == b.%1Exp", "\n\t\t&& ", prefix="return ", suffix=";"),
	() => #string JA
}

EXPONENTS_TEMPLATE :: #string TEMPLATE_Ja
(a: *SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	// The |= below is safe as by now either both exponents are the same or one is zero:
JA,
	() => fieldsTemplate(
		#string JA
	a.%Exp \%1= b.%1Exp;
	if a.%1Exp {
		a.%1Num |= b.%1Num;
		a.%1Denom |= b.%1Denom;
	} else {
		a.%1Num = 0;
		a.%1Denom = 0;
	}
JA,
		"\n"
	),
	() => #string JA

	return a;
}
TEMPLATE_Ja;

addExponents :: #insert #run tprint(EXPONENTS_TEMPLATE, "+");
subtractExponents :: #insert #run tprint(EXPONENTS_TEMPLATE, "-");

validate :: (p: SIQuantityTypeParams) #expand {
	modCheck(!p.validationError, p.validationError);
}

buildReturnType :: inline (a: SIQuantityTypeParams) #expand {
JA,
	() => fieldsTemplate(
		"\t\t%Num=a.%1Num, %1Denom=a.%1Denom, %1Exp=a.%1Exp",
		",\n",
		prefix=#string JA
`RET = #dynamic_specialize SIQuantity(
		DataType=a.DataType,
JA,
		suffix="\n\t);"
	),
	() => #string JA
}

#scope_export

//TODO: alt ones for different types with the same unit but different ratios, e.g. grams vs kilograms
operator + :: (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	modCheck(*a, dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, ratiosEqual(a, b), "UnitsError: Can only add quantities with same ratios.\n  a: [%]\n  b: [%]\n", a, b);

	return a;
}
operator + :: (a: $T/SIQuantity, b: T) -> T {
	result: T;
	result.amount = a.amount + b.amount;
	return result;
}
#if UNTYPED_ADD_SUBTRACT {
	operator + :: (a: $T/SIQuantity, b: T.DataType) -> T #symmetric {
		result: T;
		result.amount = a.amount + b;
		return result;
	}
}

operator - :: (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	modCheck(*a, dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, ratiosEqual(a, b), "UnitsError: Can only subtract quantities with same ratios.\n  a: [%]\n  b: [%]\n", a, b);

	return a;
}
operator - :: (a: $T/SIQuantity, b: T) -> T {
	result: T;
	result.amount = a.amount - b.amount;
	return result;
}
#if UNTYPED_ADD_SUBTRACT {
	operator - :: (a: $T/SIQuantity, b: T.DataType) -> T {
		result: T;
		result.amount = a.amount - b;
		return result;
	}
}

operator * :: (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	modCheck(*a, dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, ratiosCompatible(a, b), "UnitsError: Incompatible ratios.\n  a: [%]\n  b: [%]", a, b);


	addExponents(*a, b);

	return a;
}
operator * :: (x: $T/SIQuantity, y: $U/SIQuantity) -> $RET
#modify {
	a := getSIParameters(T);
	a *= getSIParameters(U);
	validate(a);


	buildReturnType(a);
	return true;
} {
	result: RET;
	result.amount = x.amount * y.amount;
	return result;
}
operator * :: (a: $T/SIQuantity, b: T.DataType) -> T #symmetric {
	result: T;
	result.amount = a.amount * b;
	return result;
}

operator / :: (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	modCheck(*a, dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, ratiosCompatible(a, b), "UnitsError: Incompatible ratios.\n  a: [%]\n  b: [%]", a, b);


	subtractExponents(*a, b);

	return a;
}
operator / :: (x: $T/SIQuantity, y: $U/SIQuantity) -> $RET
#modify {
	a := getSIParameters(T);
	a /= getSIParameters(U);
	validate(a);


	buildReturnType(a);
	return true;
} {
	result: RET;
	result.amount = x.amount / y.amount;
	return result;
}
operator / :: (a: $T/SIQuantity, b: T.DataType) -> T {
	result: T;
	result.amount = a.amount / b;
	return result;
}

ExpHolder :: struct(exp: int) { EXP :: exp; }

pow :: (pp: SIQuantityTypeParams, e: ExpHolder($EXP)) -> SIQuantityTypeParams {
	p := pp;

	#insert #run tprint(
		#string Jai
JA,
	() => fieldsTemplate("\tp.%Exp *= \%1;", "\n"),
	() => #string JA

Jai,
		EXP
	);

	return normalise(p);
}
pow :: (x: $T/SIQuantity, e: ExpHolder($EXP)) -> $RET
#modify {
	print("pow: exp = %\n", EXP);
	a := getSIParameters(T);
	a = pow(a, ExpHolder(EXP).{});
	validate(a);


	buildReturnType(a);
	return true;
} {
	result: RET;
	result.amount = xx pow(x.amount, EXP);
	return result;
}

square :: squared;
squared :: #bake_arguments (#procedure_of_call pow(SIQuantityTypeParams.{}, ExpHolder(2).{}))(e=ExpHolder(2).{});
squared :: #bake_arguments (#procedure_of_call pow(metre(), ExpHolder(2).{}))(e=ExpHolder(2).{});
cube :: cubed;
cubed :: #bake_arguments (#procedure_of_call pow(SIQuantityTypeParams.{}, ExpHolder(3).{}))(e=ExpHolder(3).{});
cubed :: #bake_arguments (#procedure_of_call pow(metre(), ExpHolder(3).{}))(e=ExpHolder(3).{});

root :: (pp: SIQuantityTypeParams, e: ExpHolder($EXP)) -> SIQuantityTypeParams {
	p := pp;

	// Exponents must be divisible by exp//LATER: consider fractional exponents?
	#insert #run tprint(
		#string Jai
JA,
	() => fieldsTemplate("p.%Exp \\\\\\% \\%1", " && ", prefix="\tif ", suffix=#string JAI
 {
		p.validationError = tprint("\\nUnitsError: Can not apply \\\%1root to non-multiples of \\\%1.\\n[\%]\\n", p);
		return p;
	}
JAI
	),
	() => #string JA
		EXP
	);

	#insert #run tprint(
		#string Jai
JA,
	() => fieldsTemplate("\tp.%Exp *= \%1;", "\n"),
	() => #string JA

Jai,
		EXP
	);

	return normalise(p);
}
root :: (x: $T/SIQuantity, e: ExpHolder($EXP)) -> $RET
#modify {
	print("root: exp = %\n", EXP);
	a := getSIParameters(T);
	a = root(a, ExpHolder(EXP).{});
	validate(a);

	buildReturnType(a);
	return true;
} {
	result : RET;
	result.amount = xx root(a.amount, 1.0 / EXP);
	return result;
}

sqrt :: #bake_arguments (#procedure_of_call root(SIQuantityTypeParams.{}, ExpHolder(2).{}))(e=ExpHolder(2).{});
sqrt :: #bake_arguments (#procedure_of_call root(metres(), ExpHolder(2).{}))(e=ExpHolder(2).{});
squareRoot :: sqrt;
cubeRoot :: #bake_arguments (#procedure_of_call root(SIQuantityTypeParams.{}, ExpHolder(3).{}))(e=ExpHolder(3).{});
cubeRoot :: #bake_arguments (#procedure_of_call root(metres(), ExpHolder(3).{}))(e=ExpHolder(3).{});

//TODO: derived units, e.g. Newtons, Joules, etc. with their own names and conversion factors, but still compatible with the base units for multiplication/division purposes.
JA
);

#import "Basic";
#import "Compiler";
#import "Math";
#import "Print_Vars";
#import "String";
