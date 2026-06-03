SIQuantity :: struct(
	DataType: Type,
	LengthNum: int, LengthDenom: int, LengthExp: int,
	MassNum: int, MassDenom: int, MassExp: int,
	TimeNum: int, TimeDenom: int, TimeExp: int
)
{
	amount : DataType;
}

#scope_file

SIQuantityTypeParams :: struct {
	#insert -> string {
		sb: String_Builder;

		ti := type_info(SIQuantity(int,0,0,0,0,0,0,0,0,0)).(*Type_Info_Struct);
		for ti.specified_parameters {
			print(*sb, "\t%: %;\n", it.name, get_type(it.type));
		}

		return builder_to_string(*sb);
	}
}

getSIParameters :: (t: Type) -> *SIQuantityTypeParams {
	ti := t.(*Type_Info_Struct);
	assert(ti.name == "SIQuantity", "Expected SIQuantity type.  Got %", t);
	return ti.constant_storage.data.(*SIQuantityTypeParams);
}

LengthUnit :: #bake_arguments SIQuantity(
	MassNum=0, MassDenom=0, MassExp=0,
	TimeNum=0, TimeDenom=0, TimeExp=0
);
//MassUnit :: #bake_arguments SIQuantity(
//	LengthNum=0, LengthDenom=0, LengthExp=0,
//	TimeNum=0, TimeDenom=0, TimeExp=0
//);
//TimeUnit :: #bake_arguments SIQuantity(
//	LengthNum=0, LengthDenom=0, LengthExp=0,
//	MassNum=0, MassDenom=0, MassExp=0
//);

Pow :: ($t: Type, exp: int) -> string #expand {
	#assert t.(*Type_Info_Struct).name == "SIQuantity";
	#insert -> string {
		p := getSIParameters(t);
		return tprint(
			#string JAI
#bake_arguments SIQuantity(
	DataType=%,
	LengthNum=%, LengthDenom=%, LengthExp=%,
	MassNum=%, MassDenom=%, MassExp=%,
	TimeNum=%, TimeDenom=%, TimeExp=%
);
JAI,
			p.DataType,
			p.LengthNum, p.LengthDenom, p.LengthExp * exp,
			p.MassNum, p.MassDenom, p.MassExp * exp,
			p.TimeNum, p.TimeDenom, p.TimeExp * exp
		);
	}
}

Squared :: #bake_arguments Pow(exp=2);
//Cubed :: #bake_arguments Pow(exp=3);

#scope_export

Meters :: #bake_arguments LengthUnit(LengthNum=1, LengthDenom=1, LengthExp=1);
//Seconds :: #bake_arguments TimeUnit(TimeNum=1, TimeDenom=1, TimeExp=1);
//Kilograms :: #bake_arguments MassUnit(MassNum=1000, MassDenom=1, MassExp=1);

Meters2 :: #run Squared(Meters);

main :: () {
	//m := Meters(float).{1};
	//print("%: %\n", m, type_of(m));
	//print("%\n", m.DataType);
}

#import "Basic";
#import "Compiler";
#import "Math";
