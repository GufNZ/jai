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

run_all :: () {
	// Placeholder for grouped test calls.
}

main :: () {
	run_all();
	print("Units tests scaffold loaded.\n");
}
