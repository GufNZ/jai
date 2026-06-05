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

/*
WORKAROUND REVERT CHECKLIST (demo):
1) Restore full ballistic formulas in calc_ballistic_range and calc_ballistic_range2.
2) Remove placeholder returns (currently return initial_height).
3) Re-validate quantity sqrt/root usage once Units root/pow paths are restored.
*/

main :: () {
	assert(tprint(tprint("\% \\\% %", 2), "A") == "A % 2", "Print bugfix for double-escaped \% needed!");
	s := MetersPerSecond(float).{5};
	g := MetersPerSecondSquared(float).{9.8};
	h := Meters(float).{1};
	range := calc_ballistic_range2(s, g, h);
	print("%\n", formatLong(range));

	s2 := KilometersPerSecond(float64).{.005};
	g2 := KilometersPerSecondSquared(float64).{.0098};
	h2 := Kilometers(float64).{0.001};
	range2 := calc_ballistic_range2(s2, g2, h2);
	print("%\n", formatLong(range2));
}

MetersPerSecond :: #insert #run SI(meters(per(second())));
MetersPerSecondSquared :: #insert #run SI(meters(per(second(squared))));

Kilometers :: #insert #run SI(kilo(meters()));
KilometersPerSecond :: #insert #run SI(kilo(meters(per(second()))));
KilometersPerSecondSquared :: #insert #run SI(kilo(meters(per(second(squared)))));

calc_ballistic_range :: (
	speed: MetersPerSecond(float),
	gravity: MetersPerSecondSquared(float),
	initial_height: Meters(float)
) -> Meters(float)
{
	// Temporary compile workaround while root/pow type transforms are disabled.
	return initial_height;
}

calc_ballistic_range2 :: (
	speed: $T/SIQuantity,
	gravity: $U/SIQuantity,
	initial_height: $V/SIQuantity
) -> $RET
#modify {
	i := getSIParameters(V);
	r := i;
	validate(r);

	buildReturnType(r);
	return true;
} {
	// Temporary compile workaround while root/pow type transforms are disabled.
	return initial_height;
}

#import "Units";
#import "Basic";
#import "Math";
