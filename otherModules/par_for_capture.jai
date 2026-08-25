_parallel_for :: (count: Code, body: Code, $captures: [$N] Code, $force_single_threaded: bool) #expand {
    #run {
        // ensure we don't list the same capture more than once else we would have duplicate member definitions on the capture struct.
        // We could just allow this and have the compiler error cover this case, but we can provide nicer error messages if it is done
        // by hand here
        validate_unique_captures(captures);
    }

    build_capture_code :: () -> string {
        type_aliases: String_Builder;
        members:      String_Builder;
        assignments: String_Builder;
        
        CAPTURE_INSERT_STRING :: #string END
            // Type aliases. Without them, the compiler runs into circular dependency errors. Probably worth an email...
            %

            Capture :: struct {
                // Members
                %
            }

            capture: Capture = ---;
            // Assignments
            %
        END

        for 0..captures.count-1 {
            name := extract_capture_name(captures[it]);
            expression := code_to_string(captures[it]);

            print_to_builder(*type_aliases, "Parallel_For_Capture_Type_% :: type_of(%);\n", it, expression);
            print_to_builder(*members,      "    %: Parallel_For_Capture_Type_%;\n", name, it);
            print_to_builder(*assignments,  "capture.% = %;\n", name, expression);
        }

        return tprint(CAPTURE_INSERT_STRING,
            builder_to_string(*type_aliases),
            builder_to_string(*members),
            builder_to_string(*assignments));
    }

    #if !force_single_threaded {
        PARALLEL_INSERT_STRING :: #string END
            {
                // Capture struct definition + member assignments
                %

                task :: (raw_data: *void, start: s64, block_count: s64) {
                    using parallel_for_capture := cast(*Capture) raw_data;

                    end := start + block_count;
                    for it: start..end-1 {
                        // Declare some landmarks which the metaprogram can use to determine file and line offset deltas.
                        // The metaprogram plugin can use them to fixup subsequent lines by computing the delta and assigning them the correct code location relative to these points.
                        parallel_for_debug_body_file :: "%";
                        parallel_for_debug_body_line :: %;

                        // Actual body:
                        %
                    }
                }

                parallel_for_raw(context.threadpool, %, *capture, task);
            }
        END

        #insert,scope(body) -> string {
            captures := build_capture_code();
            body_location := body_debug_start_location(body);


            return sprint(PARALLEL_INSERT_STRING, captures, body_location.fully_pathed_filename, body_location.line_number, code_to_string(body), code_to_string(count));
        }
    } else {
        ST_INSERT_STRING :: #string END
            {
                for 0..(%)-1 {
                    parallel_for_debug_body_file :: "%";
                    parallel_for_debug_body_line :: %;
                    %
                }
            }
        END

        #insert,scope(body) -> string {
            body_location := body_debug_start_location(body);
            return sprint(ST_INSERT_STRING , code_to_string(count), body_location.fully_pathed_filename, body_location.line_number, code_to_string(body));
        }
    }
}

