cleanFormat :: inline (value: int) -> FormatInt {
	// Just in case the caller has modified the default print_style in a way that might break the generated code, reset it:
	return .{value=value};
}
cleanFormatNoInline :: /*inline*/ (value: int) -> FormatInt {
	// Just in case the caller has modified the default print_style in a way that might break the generated code, reset it:
	return .{value=value};
}


main :: () {
	inlined := tprint("%", cleanFormat(123));
	notInlined := tprint("%", cleanFormatNoInline(123));

	print("inlined: %\n\n", inlined);
	print("not inlined: %\n\n", notInlined);

	assert(inlined == "123");
	assert(notInlined == "123", "Expected '123', got '%'", notInlined);
}
#run main();

#import "Basic";
