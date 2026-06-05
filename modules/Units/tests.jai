#import "Units";
#import "Basic";

// Intentionally minimal scaffold; assertions and conversion tests
// will be added incrementally in follow-up steps.

MetersPerSecond :: #insert #run SI(meters(per(second())));
MetersPerSecondSquared :: #insert #run SI(meters(per(second(squared))));

Kilometers :: #insert #run SI(kilo(meters()));
KilometersPerSecond :: #insert #run SI(kilo(meters(per(second()))));
KilometersPerSecondSquared :: #insert #run SI(kilo(meters(per(second(squared)))));

#assert 1.0/second() == per(second());

SumMetersType :: type_of(Meters(float64).{1} + Kilometers(float64).{1});
SumKilometersType :: type_of(Kilometers(float64).{1} + Meters(float64).{1});
SubMetersType :: type_of(Meters(float64).{1} - Kilometers(float64).{1});
SubKilometersType :: type_of(Kilometers(float64).{1} - Meters(float64).{1});

// Mixed-ratio + and - should keep the lhs unit frame.
#assert SumMetersType.MetreExp == 1 && SumMetersType.MetreNum == 1 && SumMetersType.MetreDenom == 1;
#assert SubMetersType.MetreExp == 1 && SubMetersType.MetreNum == 1 && SubMetersType.MetreDenom == 1;

#assert SumKilometersType.MetreExp == 1 && SumKilometersType.MetreNum == 1000 && SumKilometersType.MetreDenom == 1;
#assert SubKilometersType.MetreExp == 1 && SubKilometersType.MetreNum == 1000 && SubKilometersType.MetreDenom == 1;

// Offset metadata sanity checks for the conservative multiply/divide policy.
#assert Kelvin(float64).KelvinOffset == 0;
#assert Celsius(float64).KelvinOffset != 0;

// Expected compile failures (kept disabled for now):
// offset-bearing units are intentionally blocked in quantity*quantity and quantity/quantity.
#if false {
	_c_mul := Celsius(float64).{20.0} * Celsius(float64).{21.0};
	_c_div := Celsius(float64).{20.0} / Celsius(float64).{21.0};
}

test_mixed_ratio_add_sub_runtime :: () {
	a := Meters(float64).{100.0};
	b := Kilometers(float64).{2.0};

	s1 := a + b;
	assert(s1.amount > 2099.999 && s1.amount < 2100.001);

	s2 := b + a;
	assert(s2.amount > 2.099999 && s2.amount < 2.100001);

	d1 := a - b;
	assert(d1.amount > -1900.001 && d1.amount < -1899.999);

	d2 := b - a;
	assert(d2.amount > 1.899999 && d2.amount < 1.900001);
}

run_all :: () {
	test_mixed_ratio_add_sub_runtime();
}

main :: () {
	run_all();
	print("Units tests scaffold loaded.\n");
}
