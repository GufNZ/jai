main :: () {
	print(tprint("\% \\\% %\n", 2), "A");
//	s := MetersPerSecond(float).{5};
//	g := MetersPerSecond2(float).{9.8};
//	h := Meters(float).{1};
//	range := calc_ballistic_range2(s, g, h);
//	print("%\n", range);
//
//	s2 := KilometersPerSecond(float64).{.005};
//	g2 := KilometersPerSecond2(float64).{.0098};
//	h2 := Kilometers(float64).{0.001};
//	range2 := calc_ballistic_range2(s2, g2, h2);
//	print("%\n", range2);
}
#run main();
/*
MetersPerSecond :: #insert #run SI(meters(per(second())));
MetersPerSecondSquared :: #insert #run SI(meters(per(second(squared))));

Kilometers :: #insert #run SI(kilo(meters()));
KilometersPerSecond :: #insert #run SI(kilo(meters(per(second()))));
KilometersPerSecondSquared :: #insert #run SI(kilo(meters(per(second(squared)))));

calc_ballistic_range :: (
	speed: MetersPerSecond(float),
	gravity: MetersPerSecond2(float),
	initial_height: Meters(float)
) -> Meters(float)
{
	assert(speed.amount > 0.0);
	assert(gravity.amount > 0.0);
	assert(initial_height.amount >= 0.0);

	d2r : float: cast(float)0.01745329252;
	angle : float: 45.0 * d2r;
	ang_cos := cos(angle);
	ang_sin := sin(angle);

	return (speed * ang_cos / gravity)
	   * (
		speed * ang_sin
		+ sqrt(
			speed * speed * ang_sin * ang_sin
			+ 2.0 * gravity * initial_height
		)
	);
}

calc_ballistic_range2 :: (
	speed: $T/SIQuantity,
	gravity: $U/SIQuantity,
	initial_height: $V/SIQuantity
) -> $R
#modify {
	s := getSIParameters(T);
	g := getSIParameters(U);
	i := getSIParameters(V);

	r := (s / g) * (s + sqrt(square(s) + g * i));
	validate(r);


	R = buildReturnType(r);
	return true;
} {
	// Make sure units are correct:
	#assert T.MetreExp == 1 && T.KilogramExp == 0 && T.SecondExp == -1;
	#assert U.MetreExp == 1 && U.KilogramExp == 0 && U.SecondExp == -2;
	#assert V.MetreExp == 1 && V.KilogramExp == 0 && V.SecondExp == 0;

	assert(speed.amount > 0.0);
	assert(gravity.amount > 0.0);
	assert(initial_height.amount >= 0.0);

	d2r : speed.DataType: xx 0.01745329252;
	angle :: 45.0 * d2r;
	ang_cos := cos(angle);
	ang_sin := sin(angle);

	return (speed * ang_cos / gravity)
		* (
			speed * ang_sin
			+ sqrt(
				speed * speed * ang_sin * ang_sin
				+ 2.0 * gravity * initial_height
			)
		);
}

#import "Units";
*/
#import "Basic";
