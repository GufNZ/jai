#module_parameters ()(AMERICAN_SPELLING := true, UNTYPED_ADD_SUBTRACT := false, WANTED_UNITS := SIQuantities.ALL_SI_UNITS) {
	SIQuantities :: enum_flags u64 {
		NONE :: 0;

		LENGTH				:: 1 << 0;
		MASS				:: 1 << 1;
		TIME				:: 1 << 2;
		ELECTRICITY			:: 1 << 3;
		TEMPERATURE			:: 1 << 4;
		AMOUNT_OF_SUBSTANCE	:: 1 << 5;
		LUMINOUS_INTENSITY	:: 1 << 6;
		ALL_SI_UNITS		:: 0x0000_0000_007F;

		RADIANS				:: 1 << 7;
		STERADIANS			:: 1 << 8;
		DEGREES				:: 1 << 9;
		ARC_MINUTES			:: 1 << 10;
		ARC_SECONDS			:: 1 << 11;
		ALL_ANGLES			:: 0x0000_0000_0F80;

		MINUTES				:: 1 << 12;
		HOURS				:: 1 << 13;
		DAYS				:: 1 << 14;
		WEEKS				:: 1 << 15;
		HERTZ				:: 1 << 16;
		ALL_TIME			:: 0x0000_001F_F000;

		ASTRONOMICAL_UNITS	:: 1 << 17;
		LIGHT_YEARS			:: 1 << 18;
		PARSECS				:: 1 << 19;
		ALL_ASTRONOMICAL	:: 0x0000_0003_8000;

		NEWTONS				:: 1 << 20;
		PASCALS				:: 1 << 21;
		JOULES				:: 1 << 22;
		WATTS				:: 1 << 23;
		ALL_MECHANICS		:: 0x0000_F000_0000;

		COULOMBS			:: 1 << 24;
		VOLTS				:: 1 << 25;
		OHMS				:: 1 << 26;
		SIEMENS				:: 1 << 27;
		FARADS				:: 1 << 28;
		HENRYS				:: 1 << 29;
		WEBERS				:: 1 << 30;
		TESLAS				:: 1 << 31;
		ALL_ELECTRICITY		:: 0x0000_FF00_0000;

		LUMENS				:: 1 << 32;
		LUX					:: 1 << 33;
		ALL_PHOTOMETRY		:: 0x0003_0000_0000;

		BECQUERELS			:: 1 << 34;
		GRAYS				:: 1 << 35;
		SIEVERTS			:: 1 << 36;
		KATALS				:: 1 << 37;
		ALL_RADIOACTIVITY	:: 0x003C_0000_0000;

		CELSIUS				:: 1 << 38;		//QUESTION: should all these (and what they generate) have the Degrees_ prefix?
		FAHRENHEIT			:: 1 << 39;
		COMMON_TENPERATURES	:: 0x0060_0000_0000;
		RANKINE				:: 1 << 40;
		REAUER				:: 1 << 41;
		ROMER				:: 1 << 42;
		DELISLE				:: 1 << 43;
		DEGREES_NEWTON		:: 1 << 44;
		ALL_TEMPERATURES	:: 0x7FF0_0000_0000;

		ALL_DERIVED_UNITS	:: 0xFFFF_FFFF_FF80;

		EVERYTHING			:: 0xFFFF_FFFF_FFFF;
	};
};

#assert WANTED_UNITS != .NONE;
#assert WANTED_UNITS & ~.EVERYTHING == .NONE;

#if AMERICAN_SPELLING && WANTED_UNITS & .LENGTH {
	Meter :: Metre;
	Meters :: Metres;
	meter :: metre;
	meters :: metres;
}

/*
dump :: (s: $T, loc := #caller_location) -> T {
	print("\e[92mDump at %:%:%\e[0m\n", loc.fully_pathed_filename, loc.line_number, loc.character_number);
	print("\e[93m%\e[0m\n\n", replace(s, "\%", "\\%"));
	return s;
}
*/

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
		// Skip NONE & American spelling:
		if !it_index || it == "Meter"  continue;


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
#if WANTED_UNITS & .LENGTH {
	Metre;
	#if AMERICAN_SPELLING {
	Meter :: Metre;
	}
}
#if WANTED_UNITS & .MASS {
	Kilogram;
}
#if WANTED_UNITS & .TIME {
	Second;
}
#if WANTED_UNITS & .ELECTRICITY {
	Ampere;
}
#if WANTED_UNITS & .TEMPERATURE {
	Kelvin;
}
#if WANTED_UNITS & .AMOUNT_OF_SUBSTANCE {
	Mole;
}
#if WANTED_UNITS & .LUMINOUS_INTENSITY {
	Candela;
}
}

/*
Standard SI derived units with special names and definitions in terms of the 7 SI base units:
	Angles
		radian (rad)			= m/m			=	dimensionless (angle)
		steradian (sr)			= m^2/m^2		=	dimensionless (solid angle)
		degree (°)				= π/180 rad
		arcminute (′)			= 1/60 degree
		arcsecond (″)			= 1/60 arcminute

	Time & frequency
		second (s)				= base unit
		minute (min)			= 60 s
		hour (h)				= 3600 s
		day (d)					= 86400 s
		week (wk)				= 7 d
		hertz (Hz)				= 1/s

	Length & astronomical
		metre (m)				= base unit
		astronomical unit (au)	= 149597870700 m
		light-year (ly)			= 9.4607304725808e15 m
		parsec (pc)				= 3.08567756e16 m

	Mechanics (force, pressure, energy, power)
		kilogram (kg)			= base unit
		newton (N)				= kg*m/s^2
		pascal (Pa)				= kg/(m*s^2)
		joule (J)				= kg*m^2/s^2
		watt (W)				= kg*m^2/s^3

	Electricity & magnetism
		ampere (A)				= base unit
		coulomb (C)				= A*s
		volt (V)				= kg*m^2/(s^3*A)
		ohm (Ω)					= kg*m^2/(s^3*A^2)
		siemens (S)				= s^3*A^2/(kg*m^2)
		farad (F)				= s^4*A^2/(kg*m^2)
		henry (H)				= kg*m^2/(s^2*A^2)
		weber (Wb)				= kg*m^2/(s^2*A)
		tesla (T)				= kg/(s^2*A)

	Photometry
		lumen (lm)				= cd
		lux (lx)				= cd/m^2

	Radioactivity, radiation, catalysis
		becquerel (Bq)			= 1/s
		gray (Gy)				= m^2/s^2
		sievert (Sv)			= m^2/s^2
		katal (kat)				= mol/s^1

	Temperature
		kelvin (K)				= base unit
		degree Celsius (°C)		= K - 273.15
		degree Fahrenheit (°F)	= 5/9(K - 255.372222)
		degree Rankine (°R)		= 5/9 K
		degree Réaumur (°Ré)	= 0.8 K
		degree Rømer (°Rø)		= 0.525 K + 7.5 °N
		degree Delisle (°De)	= 1.5*(373.15 K - K)
		degree Newton (°N)		= 0.33 K
*/

#insert #run join(
	() => #string JAI
SIQuantity :: struct(
	DataType: Type,

JAI,
	() => fieldsTemplate("\t%Num: int, %1Denom: int, %1Exp: int, %1Scale: float, %1Offset: float", ",\n"),
	() => #string JAI

)
{
	amount : DataType;
}

SIQuantityTypeParams :: struct {
	#insert #run,stallable -> string {
		sb: String_Builder;

JAI,
	() => fieldsTemplate("0,0,0,0,0", ",", prefix="\t\tti := type_info(SIQuantity(int,", suffix="));\n"),
	() => #string JAI
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
JAI,
	() => fieldsTemplate(
		"\t%Num=parameters.%1Num, %1Denom=parameters.%1Denom, %1Exp=parameters.%1Exp, %1Scale=parameters.%1Scale, %1Offset=parameters.%1Offset",
		",\n",
		prefix="return #string JAI\n#bake_arguments SIQuantity(\n",
		suffix="\n);\nJAI;"
	),
	() => #string JAI
}

#scope_file

normalise :: (pp: SIQuantityTypeParams) -> SIQuantityTypeParams {
	p := pp;
	d: int = ---;
JAI,
	() => fieldsTemplate(
		#string JAI
	if p.%Num && p.%1Denom {
		d = gcd(p.%1Num, p.%1Denom);
		p.%1Num /= d;
		p.%1Denom /= d;
	}
JAI,
		"\n"
	),
	() => #string JAI

	return p;
}

#scope_export

JAI,
	() => fieldsTemplate(
		#string JAI
%2 :: inline (mod: (q: SIQuantityTypeParams) -> SIQuantityTypeParams, p: SIQuantityTypeParams = .{}) -> SIQuantityTypeParams {
	return %2(p, mod);
}
%2 :: (pp := SIQuantityTypeParams.{}, mod: (q: SIQuantityTypeParams) -> SIQuantityTypeParams = null) -> SIQuantityTypeParams {
	p := pp;

	p.%1Num = 1;
	p.%1Denom = 1;
	p.%1Exp = 1;
	p.%1Scale = 1.0;
	//p.%1Offset = 0.0; -- we get this for free.

	p.lastSet = .%1;

	if mod {
		p = mod(p);
	}

	return normalise(p);
}
%2s :: %2;
JAI,
		"\n",
		name => lowerInitial(name)
	),
	() => #string JAI

#scope_file

mult :: (pp: SIQuantityTypeParams, n: u64, s: float64, name: string) -> SIQuantityTypeParams {
	p := pp;

	if p.lastSet == {
JAI,
	() => fieldsTemplate(
		#string JAI
		case .%;
			p.%1Num *= n;
			p.%1Scale *= s;
JAI
	),
	() => #string JAI
		case;
			assert(false, "Can only apply % to a base SI unit.", name);
	}

	return p;
}

div :: (pp: SIQuantityTypeParams, n: u64, s: float64, name: string) -> SIQuantityTypeParams {
	p := pp;

	if p.lastSet == {
JAI,
	() => fieldsTemplate(
		#string JAI
		case .%;
			p.%1Denom *= n;
			p.%1Scale /= s;
JAI
	),
	() => #string JAI
		case;
			assert(false, "Can only apply % to a base SI unit.", name);
	}

	return p;
}

JAI,
	() -> string {
		big		:: string.["kilo",	"mega",	"giga",	"tera",	"peta",	"exa",	"zetta", "yotta"];
		small	:: string.["milli",	"micro","nano",	"pico",	"femto","atto",	"zepto", "yocto"];

		//bigBinary :: string.["kibi", "mebi", "gibi", "tebi", "pebi", "exbi", "zebi", "yobi"];

		common :: (n: u64, s: float64, it: string, proc: string) -> string {
			return tprint(
				#string JAI
% :: (p: SIQuantityTypeParams) -> SIQuantityTypeParams {
	return %(p, %, %, "%1");
}

JAI,
				it,
				proc,
				n,
				s
			);
		}

		sb: String_Builder;
		n: u64 = 1;
		s := 1.0;
		for big {
			if U64_MAX / n < 1000 {
				s *= 1000;
			} else {
				n *= 1000;
			}
			append(*sb, common(n, s, it, "mult"));
		}

		print(*sb, "\n");

		n = 1;
		s = 1.0;
		for small {
			if U64_MAX / n < 1000 {
				s /= 1000;
			} else {
				n *= 1000;
			}
			append(*sb, common(n, s, it, "div"));
		}

		return builder_to_string(*sb);
	},
	() => #string JAI

per :: (pp: SIQuantityTypeParams) -> SIQuantityTypeParams {
	p := pp;

	if p.lastSet == {
JAI,
	() => fieldsTemplate(
		#string JAI
		case .%;
			p.%1Exp = -p.%1Exp;
JAI
	),
	() => #string JAI

		case;
			assert(false, "Can only apply per to a base SI unit.");
	}

	return p;
}

#scope_file

JAI,
	() => fieldsTemplate(
		#string Jai
% :: #insert #run,stallable SI(%());
Jai,
		"\n",
		name => lowerInitial(name)
	),
	() => #string JAI

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
JAI,
	() => fieldsTemplate("\tok &&= a.%Num == b.%1Num && a.%1Denom == b.%1Denom || !a.%1Num || !b.%1Num;", "\n"),
	() => #string JAI
	return ok;
}

ratiosEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
JAI,
	() => fieldsTemplate("a.%Num == b.%1Num && a.%1Denom == b.%1Denom", "\n\t\t&& ", prefix="return ", suffix=";"),
	() => #string JAI
}

exponentsEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
JAI,
	() => fieldsTemplate("a.%Exp == b.%1Exp", "\n\t\t&& ", prefix="return ", suffix=";"),
	() => #string JAI
}

EXPONENTS_TEMPLATE :: #string TEMPLATE_JAI
(a: *SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	// The |= below is safe as by now either both exponents are the same or one is zero:
JAI,
	() => fieldsTemplate(
		#string JAI
	a.%Exp \%1= b.%1Exp;
	if a.%1Exp {
		a.%1Num |= b.%1Num;
		a.%1Denom |= b.%1Denom;
	} else {
		a.%1Num = 0;
		a.%1Denom = 0;
	}
JAI,
		"\n"
	),
	() => #string JAI

	return a;
}
TEMPLATE_JAI;

addExponents :: #insert #run tprint(EXPONENTS_TEMPLATE, "+");
subtractExponents :: #insert #run tprint(EXPONENTS_TEMPLATE, "-");

validate :: (p: SIQuantityTypeParams) #expand {
	modCheck(!p.validationError, p.validationError);
}

scalesEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
JAI,
	() => fieldsTemplate("a.%Scale == b.%1Scale", "\n\t\t&& ", prefix="return ", suffix=";"),
	() => #string JAI
}

offsetsEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
JAI,
	() => fieldsTemplate("a.%Offset == b.%1Offset", "\n\t\t&& ", prefix="return ", suffix=";"),
	() => #string JAI
}

isDimensionallyEqual :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	return dataTypesMatch(a, b) && exponentsEqual(a, b);
}

isStrictlyIdenticalUnits :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	return isDimensionallyEqual(a, b) && ratiosEqual(a, b) && scalesEqual(a, b) && offsetsEqual(a, b);
}

hasValidRatiosForActiveDimensions :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	ok := true;
JAI,
	() => fieldsTemplate(
		"\tok &&= !a.%Exp || (a.%1Num && a.%1Denom && b.%1Num && b.%1Denom);",
		"\n"
	),
	() => #string JAI
	return ok;
}

isAddSubConvertible :: inline (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> bool {
	return isDimensionallyEqual(a, b) && hasValidRatiosForActiveDimensions(a, b);
}

hasAnyOffset :: inline (p: SIQuantityTypeParams) -> bool {
JAI,
	() => fieldsTemplate("p.%Offset != 0", "\n\t\t|| ", prefix="return ", suffix=";"),
	() => #string JAI
}

isSIQuantityType :: (T: Type) -> bool {
	info := type_info(T);

	if info.type != .STRUCT  return false;
	if info.polymorph_source_struct && info.polymorph_source_struct.name == "SIQuantity"  return true;
	if info.name == "SIQuantity"  return true;	// Probably ok?


	return false;
}

ipow :: (base: float64, exponent: int) -> float64 {
	if exponent == 0  return 1.0;


	e := exponent;
	b := base;
	r := 1.0;

	if e < 0 {
		e = -e;
		b = 1.0 / b;
	}

	for 1..e {
		r *= b;
	}

	return r;
}

AddSubConversion :: struct {
	ok: bool = false;
	mul: float64 = 1.0;
	add: float64 = 0.0;
	reason: string = "";
}

MulDivOverlapConversion :: struct {
	ok: bool = false;
	rhsAdjusted: SIQuantityTypeParams;
	rhsAmountFactor: float64 = 1.0;
	reason: string = "";
}

computeAddSubConversion :: (lhs: SIQuantityTypeParams, rhs: SIQuantityTypeParams) -> AddSubConversion #compile_time {
	r: AddSubConversion;

	if !isAddSubConvertible(lhs, rhs) {
		r.reason = "UnitsError: Add/subtract requires compatible dimensions and valid unit ratios.";
		return r;
	}


	if hasAnyOffset(lhs) || hasAnyOffset(rhs) {
		r.reason = "UnitsError: Add/subtract conversion with non-zero offsets is not implemented yet.";
		return r;
	}


	m := 1.0;
JAI,
	() => fieldsTemplate(
		#string JAI
	if lhs.%1Exp {
		lhsRatio := lhs.%1Num.(float64) / lhs.%1Denom;
		rhsRatio := rhs.%1Num.(float64) / rhs.%1Denom;
		m *= ipow(rhsRatio / lhsRatio, lhs.%1Exp);
	}
JAI,
		"\n"
	),
	() => #string JAI

	r.ok = true;
	r.mul = m;
	r.add = 0.0;
	return r;
}

computeMulDivOverlapConversion :: (lhs: SIQuantityTypeParams, rhs: SIQuantityTypeParams) -> MulDivOverlapConversion #compile_time {
	r: MulDivOverlapConversion;
	r.rhsAdjusted = rhs;

	if hasAnyOffset(lhs) || hasAnyOffset(rhs) {
		r.reason = "UnitsError: Multiply/divide with non-zero unit offsets is not supported yet.";
		return r;
	}


	f := 1.0;
JAI,
	() => fieldsTemplate(
		#string JAI
	if lhs.%1Exp && rhs.%1Exp {
		if !lhs.%1Num || !lhs.%1Denom || !rhs.%1Num || !rhs.%1Denom {
			r.reason = "UnitsError: Invalid ratio metadata on overlapping active dimensions for multiply/divide conversion.";
			return r;
		}


		lhsRatio := lhs.%1Num.(float64) / lhs.%1Denom;
		rhsRatio := rhs.%1Num.(float64) / rhs.%1Denom;
		if lhsRatio != rhsRatio {
			f *= ipow(rhsRatio / lhsRatio, rhs.%1Exp);
			r.rhsAdjusted.%1Num = lhs.%1Num;
			r.rhsAdjusted.%1Denom = lhs.%1Denom;
			r.rhsAdjusted.%1Scale = lhs.%1Scale;
			r.rhsAdjusted.%1Offset = lhs.%1Offset;
		}
	}
JAI,
		"\n"
	),
	() => #string JAI

	r.ok = true;
	r.rhsAmountFactor = f;
	return r;
}

isUnit :: (t: Type, p: SIQuantityTypeParams) -> bool #compile_time {
	a := getSIParameters(t);
	return isStrictlyIdenticalUnits(a, p);
}

buildReturnType :: inline (a: SIQuantityTypeParams) #expand {
JAI,
	() => fieldsTemplate(
		"\t\t%Num=a.%1Num, %1Denom=a.%1Denom, %1Exp=a.%1Exp, %1Scale=a.%1Scale, %1Offset=a.%1Offset",
		",\n",
		prefix=#string JAI
`RET = #dynamic_specialize SIQuantity(
		DataType=a.DataType,
JAI,
		suffix="\n\t);\n"
	),
	() => #string JAI
}

#scope_export

//TODO: alt ones for different types with the same unit but different ratios, e.g. grams vs kilograms
//TEST: different types with the same unit but different scales, e.g. kelvin vs farenheit
operator + :: (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	modCheck(*a, dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, ratiosEqual(a, b), "UnitsError: Can only add quantities with same ratios.\n  a: [%]\n  b: [%]\n", a, b);


	return a;
}
operator + :: (aa: SIQuantities, b: float64) -> SIQuantityTypeParams #symmetric {
	a := aa;

	if a.lastSet == {
JAI,
	() => fieldsTemplate(
		#string JAI
		case .%;
			a.%1Offset += b;
JAI
	),
	() => #string JAI

		case;
			assert(false, "Can only apply +offset to a base SI unit.");
	}

	return a;
}
operator + :: (a: $T/SIQuantity, b: T) -> T {
	result: T;
	result.amount = a.amount + b.amount;
	return result;
}
operator + :: (a: $T/SIQuantity, b: $U/SIQuantity, $MUL: float64 = 1.0, $ADD: float64 = 0.0) -> $RET
#modify {
	// Prefer the existing same-type overload for the minimal runtime path.
	if T == U  return false, "Prefer the same-type `+` overload.";

	lhs := getSIParameters(T);
	rhs := getSIParameters(U);

	modCheck(dataTypesMatch(lhs, rhs), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", lhs, rhs);


	conv := computeAddSubConversion(lhs, rhs);
	modCheck(conv.ok, conv.reason);


	MUL = conv.mul;
	ADD = conv.add;

	buildReturnType(lhs);
	return true;
} {
	result: RET;
	result.amount = a.amount + (b.amount * (xx MUL) + (xx ADD));
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
operator - :: (aa: SIQuantities, b: float64) -> SIQuantityTypeParams {
	a := aa;

	if a.lastSet == {
JAI,
	() => fieldsTemplate(
		#string JAI
		case .%;
			a.%1Offset -= b;
JAI
	),
	() => #string JAI

		case;
			assert(false, "Can only apply -offset to a base SI unit.");
	}

	return a;
}
operator - :: (b: float64, aa: SIQuantities) -> SIQuantityTypeParams {
	a := aa;

	if a.lastSet == {
JAI,
	() => fieldsTemplate(
		#string JAI
		case .%;
			a.%1Offset += b;
			a.%1Scale = -a.%1Scale;
JAI
	),
	() => #string JAI

		case;
			assert(false, "Can only apply offset- to a base SI unit.");
	}

	return a;
}
operator - :: (a: $T/SIQuantity, b: T) -> T {
	result: T;
	result.amount = a.amount - b.amount;
	return result;
}
operator - :: (a: $T/SIQuantity, b: $U/SIQuantity, $MUL: float64 = 1.0, $ADD: float64 = 0.0) -> $RET
#modify {
	// Prefer the existing same-type overload for the minimal runtime path.
	if T == U  return false, "Prefer the same-type `-` overload.";

	lhs := getSIParameters(T);
	rhs := getSIParameters(U);

	modCheck(dataTypesMatch(lhs, rhs), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", lhs, rhs);


	conv := computeAddSubConversion(lhs, rhs);
	modCheck(conv.ok, conv.reason);


	MUL = conv.mul;
	ADD = conv.add;

	buildReturnType(lhs);
	return true;
} {
	result: RET;
	result.amount = a.amount - (b.amount * (xx MUL) + (xx ADD));
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
	modCheck(*a, ratiosCompatible(a, b), "UnitsError: Incompatible ratios for multiply.\n  Overlapping active dimensions must currently use the same ratio metadata.\n  Mixed-ratio multiply auto-conversion is not implemented yet.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, !hasAnyOffset(a) && !hasAnyOffset(b), "UnitsError: Multiply with non-zero unit offsets is not supported yet.\n  a: [%]\n  b: [%]", a, b);


	addExponents(*a, b);

	return a;
}
operator * :: (aa: SIQuantities, b: float64) -> SIQuantityTypeParams #symmetric {
	a := aa;

	if a.lastSet == {
JAI,	() => fieldsTemplate(
		#string JAI
		case .%;
			a.%1Scale *= b;
JAI
	),
	() => #string JAI

		case;
			assert(false, "Can only apply *scale to a base SI unit.");
	}

	return a;
}
operator * :: (x: $T/SIQuantity, y: $U/SIQuantity, $RHS_FACTOR: float64 = 1.0) -> $RET
#modify {
	a := getSIParameters(T);
	b := getSIParameters(U);

	modCheck(dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);


	conv := computeMulDivOverlapConversion(a, b);
	modCheck(conv.ok, conv.reason);


	RHS_FACTOR = conv.rhsAmountFactor;

	a *= conv.rhsAdjusted;
	validate(a);


	buildReturnType(a);
	return true;
} {
	result: RET;
	result.amount = x.amount * y.amount * (xx RHS_FACTOR);
	return result;
}
operator * :: (a: $T/SIQuantity, b: T.DataType) -> T #symmetric {
	result: T;
	result.amount = a.amount * b;
	return result;
}

operator / :: (a: SIQuantityTypeParams, b: SIQuantityTypeParams) -> SIQuantityTypeParams {
	modCheck(*a, dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, ratiosCompatible(a, b), "UnitsError: Incompatible ratios for divide.\n  Overlapping active dimensions must currently use the same ratio metadata.\n  Mixed-ratio divide auto-conversion is not implemented yet.\n  a: [%]\n  b: [%]", a, b);
	modCheck(*a, !hasAnyOffset(a) && !hasAnyOffset(b), "UnitsError: Divide with non-zero unit offsets is not supported yet.\n  a: [%]\n  b: [%]", a, b);


	subtractExponents(*a, b);

	return a;
}
operator / :: (aa: SIQuantities, b: float64) -> SIQuantityTypeParams {
	a := aa;

	if a.lastSet == {
JAI,	() => fieldsTemplate(
		#string JAI
		case .%;
			a.%1Scale /= b;
JAI
	),
	() => #string JAI

		case;
			assert(false, "Can only apply /scale to a base SI unit.");
	}

	return a;
}
operator / :: (b: float64, aa: SIQuantities) -> SIQuantityTypeParams {
	a := aa;

	if a.lastSet == {
JAI,	() => fieldsTemplate(
		#string JAI
		case .%;
			a.%1Scale *= b;
			a.%1Denom = -a.%1Denom;
JAI
	),
	() => #string JAI

		case;
			assert(false, "Can only apply /scale to a base SI unit.");
	}

	return a;
}
operator / :: (x: $T/SIQuantity, y: $U/SIQuantity, $RHS_FACTOR: float64 = 1.0) -> $RET
#modify {
	a := getSIParameters(T);
	b := getSIParameters(U);

	modCheck(dataTypesMatch(a, b), "UnitsError: Quantities must have same DataType.\n  a: [%]\n  b: [%]", a, b);


	conv := computeMulDivOverlapConversion(a, b);
	modCheck(conv.ok, conv.reason);


	RHS_FACTOR = conv.rhsAmountFactor;

	a /= conv.rhsAdjusted;
	validate(a);


	buildReturnType(a);
	return true;
} {
	result: RET;
	result.amount = x.amount / (y.amount * (xx RHS_FACTOR));
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
JAI,
	() => fieldsTemplate("\tp.%Exp *= \%1;", "\n"),
	() => #string JAI

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
JAI,
	() => fieldsTemplate("p.%Exp \\\\\\% \\%1", " && ", prefix="\tif ", suffix=#string JAI
 {
		p.validationError = tprint("\\nUnitsError: Can not apply \\\%1root to non-multiples of \\\%1.\\n[\%]\\n", p);
		return p;
	}
JAI
	),
	() => #string JAI
		EXP
	);

	#insert #run tprint(
		#string Jai
JAI,
	() => fieldsTemplate("\tp.%Exp /= \%1;", "\n"),
	() => #string JAI

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

unboxSI :: (x: $T/SIQuantity) -> T.DataType {
	return x.amount;
}

boxSI :: (target: $T/Type, value: T.DataType) -> T
#modify {
	return isSIQuantityType(T), tprint("Type % is not a SIQuantity type", T);
} {
	result: T;
	result.amount = value;
	return result;
}

//TEST: can we handle dimensionless units?
#if WANTED_UNITS & .RADIANS {
	Radian :: #insert #run,stallable SI(meter(per(meter())));
}
#if WANTED_UNITS & .STERADIANS {
	Steradian :: #insert #run,stallable SI(meter(squared(per(meter(squared)))));
}
#if WANTED_UNITS & .DEGREES {
	Degree :: #insert #run,stallable SI(meter(per(meter() * (180.0 / PI64))));
}
#if WANTED_UNITS & .ARC_MINUTES {
	ArcMinute :: #insert #run,stallable SI(meter(per(meter() * (180.0 / (PI64 * 60.0)))));
}
#if WANTED_UNITS & .ARC_SECONDS {
	ArcSecond :: #insert #run,stallable SI(meter(per(meter() * (180.0 / (PI64 * 60.0 * 60.0)))));
}

#if WANTED_UNITS & .MINUTES {
	Minute :: #insert #run,stallable SI(second() * 60.0);
}
#if WANTED_UNITS & .HOURS {
	Hour :: #insert #run,stallable SI(second() * (60.0 * 60.0));
}
#if WANTED_UNITS & .DAYS {
	Day :: #insert #run,stallable SI(second() * (60.0 * 60.0 * 24.0));
}
#if WANTED_UNITS & .WEEKS {
	Week :: #insert #run,stallable SI(second() * (60.0 * 60.0 * 24.0 * 7.0));
}
#if WANTED_UNITS & .HERTZ {
	Hertz :: #insert #run,stallable SI(per(second()));
}

#if WANTED_UNITS & .ASTRONOMICAL_UNITS {
	AstronomicalUnit :: #insert #run,stallable SI(meter() * 149597870700.0);
}
#if WANTED_UNITS & .LIGHT_YEARS {
	LightYear :: #insert #run,stallable SI(meter() * 9.4607304725808e15);
}
#if WANTED_UNITS & .PARSECS {
	Parsec :: #insert #run,stallable SI(meter() * 3.08567756e16);
}

#if WANTED_UNITS & .NEWTONS {
	Newton :: #insert #run,stallable SI(kilogram() * meter(per(second(squared))));
}
#if WANTED_UNITS & .PASCALS {
	Pascal :: #insert #run,stallable SI(kilogram() * per(meter() * second(squared())));
}
#if WANTED_UNITS & .JOULES {
	Joule :: #insert #run,stallable SI(kilogram() * meter(squared(per(second(squared)))));
}
#if WANTED_UNITS & .WATTS {
	Watt :: #insert #run,stallable SI(kilogram() * meter(squared(per(second(squared) * second()))));
}
#if WANTED_UNITS & .COULOMBS {
	Coulomb :: #insert #run,stallable SI(ampere() * second());
}
#if WANTED_UNITS & .VOLTS {
	Volt :: #insert #run,stallable SI(kilogram() * meter(squared(per(second(squared) * ampere()))));
}
#if WANTED_UNITS & .OHMS {
	Ohm :: #insert #run,stallable SI(kilogram() * meter(squared(per(second(squared) * ampere(squared)))));
}
#if WANTED_UNITS & .SIEMENS {
	Siemens :: #insert #run,stallable SI(second(squared) * ampere(squared(per(kilogram() * meter(squared)))));
}
#if WANTED_UNITS & .FARADS {
	Farad :: #insert #run,stallable SI(second(squared) * ampere(squared(per(kilogram() * meter(squared)))));
}
#if WANTED_UNITS & .HENRYS {
	Henry :: #insert #run,stallable SI(kilogram() * meter(squared(per(second(squared) * ampere(squared)))));
}
#if WANTED_UNITS & .WEBERS {
	Weber :: #insert #run,stallable SI(kilogram() * meter(squared(per(second(squared) * ampere()))));
}
#if WANTED_UNITS & .TESLAS {
	Tesla :: #insert #run,stallable SI(kilogram() * per(second(squared) * ampere()));
}

#if WANTED_UNITS & .LUMENS {
	Lumen :: Candela;
}
#if WANTED_UNITS & .LUX {
	Lux :: #insert #run,stallable SI(candela() * per(meter(squared)));
}

#if WANTED_UNITS & .BECQUERELS {
	Becquerel :: #insert #run,stallable SI(per(second()));
}
#if WANTED_UNITS & .GRAYS {
	Gray :: #insert #run,stallable SI(meter(squared) * per(second(squared)));
}
#if WANTED_UNITS & .SIEVERTS {
	Sievert :: #insert #run,stallable SI(meter(squared) * per(second(squared)));
}
#if WANTED_UNITS & .KATALS {
	Katal :: #insert #run,stallable SI(mole() * per(second()));
}

#if WANTED_UNITS & .CELSIUS {
	Celsius :: #insert #run,stallable SI(kelvin() - 273.15);
}
#if WANTED_UNITS & .FAHRENHEIT {
	Fahrenheit :: #insert #run,stallable SI((kelvin() - 255.372222) * (5.0 / 9.0));
}
#if WANTED_UNITS & .RANKINE {
	Rankine :: #insert #run,stallable SI(kelvin() * (5.0 / 9.0));
}
#if WANTED_UNITS & .REAUER {
	Reauer :: #insert #run,stallable SI(kelvin() * 0.8);
}
#if WANTED_UNITS & .ROMER {
	Romer :: #insert #run,stallable SI(kelvin() * 0.525 + 7.5 * celsius());
}
#if WANTED_UNITS & .DELISLE {
	Delisle :: #insert #run,stallable SI((373.15 - kelvin()) * 1.5);
}
#if WANTED_UNITS & .DEGREES_NEWTON {
	DegreesNewton :: #insert #run,stallable SI(kelvin() * 0.33);
}
JAI
);

#import "Basic";
#import "Compiler";
#import "Math";
#import "Print_Vars";
#import "String";
