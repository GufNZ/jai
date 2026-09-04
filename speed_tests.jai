#import "Basic";
#import "Machine_X64";
#import "Math";
#import "Random";
#import "Sort";

log2 :: (x: float64) -> float64 {
	return log(x) / #run log(2.0);
}

asmVersion :: (requestedSize: s64) -> s64 {
	if requestedSize <= 16 {
		return 4;
	}


	result: s64 = ---;
	#asm {
		sub requestedSize, 1;			// we want ceil not floor, hence -1.
		bsr result, requestedSize;		// result = floor(log2(requestedSize)).
		add result, 1;					// we ceil not floor, hence +1.
	}
	return result;
}

mathVersion :: (requestedSize: s64) -> s64 {
	return max(4, ceil(log2(xx requestedSize)).(s64));
}

loopVersion :: (requestedSize: s64) -> s64 {
	size : s64 = 4;
	length := 1<<size;
	while length < requestedSize {
		size += 1;
		length <<= 1;
	}

	return size;
}

searchVersion :: (requestedSize: s64) -> s64 {
	size := 4;

	if requestedSize <= 16 {
		return size;
	}


	x := (requestedSize - 1) >> 4;	// we want ceil not floor, hence -1.

	if x >= (1 << 32) {	x >>= 32;	size += 32;	}
	if x >= (1 << 16) {	x >>= 16;	size += 16;	}
	if x >= (1 <<  8) {	x >>=  8;	size +=  8;	}
	if x >= (1 <<  4) {	x >>=  4;	size +=  4;	}
	if x >= (1 <<  2) {	x >>=  2;	size +=  2;	}
	if x >= (1 <<  1) {				size +=  1;	}

	return size + 1;				// we want ceil not floor, hence +1.
}

BUGGY_VERSION :: false;

Pair :: struct {
	n: s64;
	k: s64;
	r: s64;
	ex: s64;
};

Test :: struct {
	f: #type (s64) -> s64;
	name: string;
	cycles: u64;
	ratio: float64;
};

NUM_TESTS :: 10_000_000;
RUNS :: 50;
pairs: []Pair;

main :: () {
	pairs = NewArray(NUM_TESTS, Pair);

	random_seed(42);

	for * pairs {
		it.n = it_index + 1;
		it.k = xx,no_check random_get();
		it.ex = loopVersion(it.n);
	}

	#if BUGGY_VERSION {
		quick_sort(pairs, (a, b) => a.k - b.k);
	} else {
		quick_sort(pairs, (a) => a.k);
	}


	tests := Test.[
		{f=mathVersion,		name="  mathVersion"},
		{f=loopVersion,		name="  loopVersion"},
		{f=searchVersion,	name="searchVersion"},
		{f=asmVersion,		name="   asmVersion"},
	];

	for 1..RUNS {
		print("Run % of %\n", it, RUNS);
		minCycles: u64 = 0xFFFFFFFFFFFFFFFF;
		for * t: tests {
			start := rdtsc();
			for * pairs {
				it.r = t.f(it.n);
			}
			end := rdtsc();
			t.cycles = end - start;
			if t.cycles < minCycles {
				minCycles = t.cycles;
			}

			if it==1 {
				for pairs {
					if it.r != it.ex {
						print("BUG: % [%] % != %\n", t.name, it.n, it.r, it.ex);
					}
				}
			}
		}

		for * t: tests {
			ratio := 1.0 * t.cycles / minCycles;
			t.ratio += ratio;
			print("% cycles: %,\t%x\n", t.name, t.cycles, ratio);
		}
	}

	print("\n\n");

	for t: tests {
		ratio := t.ratio / RUNS;
		print("% average ratio: %\n", t.name, ratio);
	}

	//for pairs {
	//	print("[%] = %\t:: %\t\t(0x% = %)\n", it_index, it.n, it.r, FormatInt.{value=it.k, base=16, minimum_digits=16}, it.k);
	//}
}
