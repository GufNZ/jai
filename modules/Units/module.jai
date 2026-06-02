#module_parameters ()(AMERICAN_SPELLING := false, UNTYPED_ADD_SUBTRACT := false);

#if AMERICAN_SPELLING {
	Meter :: Metre;
	Meters :: Metres;
	meter :: metre;
	meters :: metres;
}

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

#insert #run tprint(
	#string JAI
SIQuantity :: struct(
	DataType: Type,

%
)
{
	amount : DataType;
}
JAI,
	fieldsTemplate("\t%Num: int, %1Denom: int, %1Exp: int", ",\n")
);

#scope_file

fieldsTemplate :: (template: string, joiner := "", alt: (name: string) -> string = null, prefix := "", suffix := "") -> string {
	sb: String_Builder;

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
			print(*sb, template, it, alt(it));
		} else {
			print(*sb, template, it);
		}
	}

	if suffix {
		print(*sb, suffix);
	}

	return builder_to_string(*sb);
}

SIQuantityTypeParams :: struct {
	#insert -> string {
		sb: String_Builder;

		#insert #run fieldsTemplate("0,0,0", ",", prefix="ti := type_info(SIQuantity(int,", suffix="));");
		for ti.specified_parameters {
			print(*sb, "\t%: %;\t// @ %\n", it.name, get_type(it.type), it.offset_into_constant_storage);
		}

		print(*sb, "\n\tlastSet: SIUnit;\n");

		return builder_to_string(*sb);
	}

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
	return tprint(
		tprint(
			#string JAI
#bake_arguments SIQuantity(
$
);
JAI,
			fieldsTemplate("%Num=\%, %Denom=\%, %Exp=\%,")
		),
		#insert #run fieldsTemplate("\t\tparameters.%Num, parameters.%Denom, parameters.%Exp", ",\n"),
	);
}

normalise :: (pp: SIQuantityTypeParams) -> SIQuantityTypeParams {
	p := pp;
	d: int = ---;

	#insert #run fieldsTemplate(
		#string JAI
	if p.%Num > 1 && p.%1Denom > 1 {
		d = gcd(p.%1Num, p.%1Denom);
		p.%1Num /= d;
		p.%1Denom /= d;
	}
JAI,
		"\n"
	);

	return p;
}

#insert #run fieldsTemplate(
	#string JAI
%2 :: %2s;
%2s :: inline (mod: (q: SIQuantityTypeParams) -> SIQuantityTypeParams, p: SIQuantityTypeParams = .{}) -> SIQuantityTypeParams {
	return %s(p, mod);
}
%2s :: (pp := SIQuantityTypeParams.{}, mod: (q: SIQuantityTypeParams) -> SIQuantityTypeParams = null) -> SIQuantityTypeParams {
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
JAI,
	"\n",
	name => lowerInitial(name)
);

big		:: string.["kilo",	"mega",	"giga",	"tera",	"peta",	"exa",	/* Too big for int: "zetta", "yotta"*/];
small	:: string.["milli",	"micro","nano",	"pico",	"femto","atto",	/* Too big for int: "zepto", "yocto"*/];

//bigBinary :: string.["kibi", "mebi", "gibi", "tebi", "pebi", "exbi", /* Too big for int: "zebi", "yobi"*/];

#scope_export

#insert -> string {
	common :: (sb: *String_Builder, n: u64, field: string) -> string {
		print(
			sb, #string JAI
% :: (pp: SIQuantityTypeParams) -> SIQuantityTypeParams {
	p := pp;
	if p.lastSet == {
%

		case;
			assert(false, "Can only apply %1 to a base SI unit.");
	}

	return p;
}
JAI,
			it,
			replace(
				fieldsTemplate(
					tprint(
						#string JAI
		case .\%;
			p.\%1% *= #;
JAI,
						field
					)
				),
				"#",
				tprint("%", n)
			)
		);
	};

	sb: String_Builder;
	n :u64= 1;
	for big {
		n *= 1000;
		common(*sb, n, "Num");
	}

	print(*sb, "\n");

	n = 1;
	for small {
		n *= 1000;
		common(*sb, n, "Denom");
	}

	return builder_to_string(*sb);
}

per :: (pp: SIQuantityTypeParams) -> SIQuantityTypeParams {
	p := pp;

	#insert #run tprint(
		#string JAI
	if p.lastSet == {
%

		case;
			assert(false, "Can only apply per to a base SI unit.");
	}
JAI,
		fieldsTemplate(#string JAI
		case .%;
			p.%1Exp = -p.%1Exp;
JAI
		)
	);

	return p;
}

gcd :: (a: int, b: int) -> int {
	while b {
		a, b = b, a % b;
	}

	return a;
}

#scope_file

#insert #run fieldsTemplate(
	#string JAI
% :: #insert #run SI(%());
JAI,
	"\n",
	name => lowerInitial(name)
);

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
	#insert #run fieldsTemplate("\tok &&= a.%Num == b.%1Num && a.%1Denom == b.%1Denom || !a.%1Num || !b.%1Num;", "\n");
	return ok;
}

ratiosEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	#insert #run fieldsTemplate("a.%Num == b.%1Num && a.%1Denom == b.%1Denom", "\n\t\t&& ", prefix="return ", suffix=";");
}

exponentsEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	#insert #run fieldsTemplate("a.%Exp == b.%1Exp", "\n\t\t&& ", prefix="return ", suffix=";");
}

EXPONENTS_TEMPLATE :: #string,\% TEMPLATE_JAI
(a: *SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	// The |= below is safe as by now either both exponents are the same or one is zero:
	#insert #run fieldsTemplate(
		#string JAI
	a.\%Exp %1= b.\%1Exp;
	if a.\%1Exp {
		a.\%1Num |= b.\%1Num;
		a.\%1Denom |= b.\%1Denom;
	} else {
		a.\%1Num = 0;
		a.\%1Denom = 0;
	}
JAI,
		"\n"
	);

	return a;
}
TEMPLATE_JAI;

addExponents :: #insert #run tprint(EXPONENTS_TEMPLATE, "+");
subtractExponents :: #insert #run tprint(EXPONENTS_TEMPLATE, "-");

validate :: (p: SIQuantityTypeParams) #expand {
	modCheck(!p.validationError, p.validationError);
}

buildReturnType :: inline (a: SIQuantityTypeParams) #expand {
	#insert #run fieldsTemplate(
		"\t\t%Num=a.%1Num, %1Denom=a.%1Denom, %1Exp=a.%1Exp",
		",\n",
		prefix=#string JAI
RET = #dynamic_specialize SIQuantity(
		DataType=a.DataType,
JAI,
		suffix="\n\t);"
	);
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

#scope_file

ExpHolder :: struct(exp: int) { EXP :: exp; }

#scope_export

pow :: (pp: SIQuantityTypeParams, exp: int) -> SIQuantityTypeParams {
	p := pp;

	#insert #run fieldsTemplate(tprint("p.\%Exp *= %;", 42/*exp*/), "\n");

	return normalise(p);
}
pow :: (x: $T/SIQuantity, exp: $E/ExpHolder) -> $RET
#modify {
	a := getSIParameters(T);
	ti := E.(*Type_Info_Struct);
	a = (#procedure_of_call pow(SIQuantityTypeParams.{}, 1))(a, ti.constant_storage.data.(*int).*);
	validate(a);


	buildReturnType(a);
	return true;
} {
	result: RET;
	result.amount = xx pow(x.amount, exp);
	return result;
}

square :: squared;
squared :: #bake_arguments (#procedure_of_call pow(SIQuantityTypeParams.{}, 1))(exp=2);
squared :: #bake_arguments (#procedure_of_call pow(metre(int), 1))(exp=2);
cube :: cubed;
cubed :: #bake_arguments (#procedure_of_call pow(SIQuantityTypeParams.{}, 1))(exp=3);
cubed :: #bake_arguments (#procedure_of_call pow(metre(int), 1))(exp=3);

root :: (pp: SIQuantityTypeParams, exp: int) -> SIQuantityTypeParams {
	p := pp;

	// Exponents must be divisible by exp//LATER: consider fractional exponents?
	#insert #run fieldsTemplate(tprint("p.\%Exp \\\% %", 2/*exp*/), " || ", prefix="if ", suffix=#string JAI
 {
		p.validationError = tprint("\nUnitsError: Can not apply %root to non-multiples of %1.\n[%2]\n", exp, p);
		return p;
	}
JAI
	);

	#insert #run fieldsTemplate(tprint("p.\%Exp /= %", 2/*exp*/), "\n");

	return normalise(p);
}
root :: (x: $T/SIQuantity, exp: $E/ExpHolder) -> $RET
#modify {
	a := getSIParameters(T);
	ti := E.(*Type_Info_Struct);
	a = root(a, ti.constant_storage.data.(*int).*);
	validate(a);

	buildReturnType(a);
	return true;
} {
	result : RET;
	result.amount = xx pow(a.amount, 1.0 / exp.exp);
	return result;
}

sqrt :: #bake_arguments (#procedure_of_call root(SIQuantityTypeParams.{}, 1))(exp=2);
sqrt :: #bake_arguments (#procedure_of_call root(metres(int), 1))(exp=2);
squareRoot :: sqrt;
cubeRoot :: #bake_arguments (#procedure_of_call root(SIQuantityTypeParams.{}, 1))(exp=3);
cubeRoot :: #bake_arguments (#procedure_of_call root(metres(int), 1))(exp=3);

//TODO: derived units, e.g. Newtons, Joules, etc. with their own names and conversion factors, but still compatible with the base units for multiplication/division purposes.

formatLong :: (v: Any) -> FormatStruct {
	return FormatStruct.{
		value = v,
		draw_type_name = true,
		use_long_form_if_more_than_this_many_members = -1,
		use_newlines_if_long_form = true,
		begin_string = "\e[91m.{\e[92m",
		end_string = "\e[91m}\e[0m",
		separator_between_name_and_value = "\e[93m = \e[94m",
		long_form_separator_between_fields = "\e[95m;\e[92m",
		recursive_long_form_depth = -1,
	};
}

#import "Basic";
#import "Compiler";
#import "Math";
#import "Print_Vars";
#import "String";
