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
MulMetersType :: type_of(Meters(float64).{2} * Kilometers(float64).{3});
MulKilometersType :: type_of(Kilometers(float64).{3} * Meters(float64).{2});
DivMetersType :: type_of(Meters(float64).{2000} / Kilometers(float64).{2});
DivKilometersType :: type_of(Kilometers(float64).{2} / Meters(float64).{2000});

// Mixed-ratio + and - should keep the lhs unit frame.
#assert SumMetersType.MetreExp == 1 && SumMetersType.MetreNum == 1 && SumMetersType.MetreDenom == 1;
#assert SubMetersType.MetreExp == 1 && SubMetersType.MetreNum == 1 && SubMetersType.MetreDenom == 1;

#assert SumKilometersType.MetreExp == 1 && SumKilometersType.MetreNum == 1000 && SumKilometersType.MetreDenom == 1;
#assert SubKilometersType.MetreExp == 1 && SubKilometersType.MetreNum == 1000 && SubKilometersType.MetreDenom == 1;

// Mixed-ratio * and / should preserve lhs ratio-frame for overlapping dimensions.
#assert MulMetersType.MetreExp == 2 && MulMetersType.MetreNum == 1 && MulMetersType.MetreDenom == 1;
#assert MulKilometersType.MetreExp == 2 && MulKilometersType.MetreNum == 1000 && MulKilometersType.MetreDenom == 1;
#assert DivMetersType.MetreExp == 0 && DivMetersType.MetreNum == 0 && DivMetersType.MetreDenom == 0;
#assert DivKilometersType.MetreExp == 0 && DivKilometersType.MetreNum == 0 && DivKilometersType.MetreDenom == 0;

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

test_mixed_ratio_mul_div_runtime :: () {
	m := Meters(float64).{2.0};
	km := Kilometers(float64).{3.0};

	p1 := m * km;
	assert(p1.amount > 5999.999 && p1.amount < 6000.001);

	p2 := km * m;
	assert(p2.amount > 0.005999 && p2.amount < 0.006001);

	d1 := Meters(float64).{2000.0} / Kilometers(float64).{2.0};
	assert(d1.amount > 0.999999 && d1.amount < 1.000001);

	d2 := Kilometers(float64).{2.0} / Meters(float64).{2000.0};
	assert(d2.amount > 0.999999 && d2.amount < 1.000001);
}

run_all :: () {
	test_mixed_ratio_add_sub_runtime();
	test_mixed_ratio_mul_div_runtime();
}

main :: () {
	run_all();
	print("Units tests scaffold loaded.\n");
}
