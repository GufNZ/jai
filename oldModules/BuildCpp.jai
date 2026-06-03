// This module helps build C/C++ libraries and programs from jai.
// It’s _not_ intended to replace C++ build tools for complex projects. It doesn’t even try to do anything fancy.
// But it’s handy if you quickly need to compile a handfull of C/C++ files into an executable, a static library, or a dynamic library without wanting to think about the platform specifics.
//
// It can only be run at compile-time for now (since it uses compiler_report).
//
// See modules/ImGui/generate.jai or modules/Bindings_Generator/examples/first.jai for usage examples.

#module_parameters () (PS5_SUPPORT := false, NINTENDO_SUPPORT := false);

Build_Type :: enum {
    STATIC_LIBRARY;
    DYNAMIC_LIBRARY;
    EXECUTABLE;
    OBJ_FILE;
}

build_cpp_static_lib  :: #bake_arguments build_cpp(type = .STATIC_LIBRARY);
build_cpp_dynamic_lib :: #bake_arguments build_cpp(type = .DYNAMIC_LIBRARY);
build_cpp_executable  :: #bake_arguments build_cpp(type = .EXECUTABLE);

// compiler_executable_path and ar_executable_path are only used for non-Windows builds atm. If it’s empty, compiler_executable_path is inferred from CC / CXX environment variables and otherwise falls back to "clang"/"clang++"
build_cpp :: (output_basename: string, files: ..string, type: Build_Type, debug := false, extra: [] string = .[], library_files: [] string = .[], target := OS, compiler_executable_path := "", ar_executable_path := "", working_directory := "", loc := #caller_location) -> bool {
    auto_release_temp();
    push_allocator(temp);

    arguments: [..] string;

    output_filename: string;
    if target == .WINDOWS {
        if #complete type == {
            case .STATIC_LIBRARY;
                output_filename = tprint("%.lib", output_basename);
            case .DYNAMIC_LIBRARY;
                output_filename = tprint("%.dll", output_basename);
            case .EXECUTABLE;
                output_filename = tprint("%.exe", output_basename);
            case .OBJ_FILE;
                output_filename = tprint("%.obj", output_basename);
        }

        #if OS == .WINDOWS {
            path_overwrite_separators(output_filename, #char "\\");

            vc_path, linker_path := find_visual_studio_in_a_ridiculous_garbage_way();

            kit_root := find_windows_kit_root();
            if !kit_root {
                compiler_report("Unable to find Windows Kit root; can't compile.\n", loc);
                return false;
            }
        } else {
            compiler_report("Unable to find Visual Studio; can't compile.\n", loc);
            vc_path, linker_path: string;
            kit_root: string;
            return false; // Visual studio is not available in non-windows OS.
        }

        linker := join(linker_path, "\\", "cl.exe");
        array_add(*arguments, linker);

        array_add(*arguments, "/nologo");

        // Include directories:
        vc_include_path := join(vc_path, "\\..\\..\\include");
        kit_root_include := replace(kit_root, "Lib", "Include");
        array_add(*arguments,
            tprint("/I%", vc_include_path),
            tprint("/I%\\um", kit_root_include),
            tprint("/I%\\ucrt", kit_root_include),
            tprint("/I%\\shared", kit_root_include),
        );

        // Definitions:
        array_add(*arguments, "/DWIN32");
        if debug {
            array_add(*arguments, "/DDEBUG");
        }

        // Compiler options:
        if debug {
            array_add(*arguments, "/Od");   // Disable optimizations.
        } else {
            array_add(*arguments,
                "/O2",                      // Maximize speed.
                "/Oi",                      // Enable intrinsics.
            );
        }
        array_add(*arguments, "/W3");

        if debug {
            array_add(*arguments,
                "/DEBUG",                   // Generate debug info.
                "/Zi",                      // Generate pdb file.
                tprint("/Fd%.pdb", output_basename), // Sets name of pdb file.
            );
        }

        array_add(*arguments,
            "-diagnostics:caret",
            "-diagnostics:column"
        );

        array_add(*arguments, .. extra);

        // Add files:
        objs: [..] string;
        array_reserve(*objs, files.count);
        for files {
            src := copy_temporary_string(it);
            path_overwrite_separators(src);
            array_add(*arguments, src);

            array_add(*objs, tprint("%.obj", path_strip_extension(path_filename(it))));
        }

        // Make sure to cleanup the resulting obj files.
        defer {
            if type != .OBJ_FILE {
                for objs file_delete(it);
            }

            if type == .DYNAMIC_LIBRARY then file_delete(tprint("%.exp", output_basename));
        }

        if type == .STATIC_LIBRARY || type == .OBJ_FILE {
            array_add(*arguments, "/c");        // Compile without linking.
        } else {
            array_add(*arguments, "/link");

            // Linker options:
            if type == .DYNAMIC_LIBRARY {
                array_add(*arguments, "/DLL");
            }
            array_add(*arguments,
                "/MACHINE:AMD64",
                tprint("/OUT:%", output_filename),
                tprint("/libpath:%", vc_path),
                tprint("/libpath:%\\um\\x64", kit_root),
                tprint("/libpath:%\\ucrt\\x64", kit_root),
                "/INCREMENTAL:NO",
            );
        }

        array_add(*arguments, .. library_files);

        log("%", get_quoted_command_string(arguments));
        result, output_string, error_string := run_command(..arguments, capture_and_return_output = true, print_captured_output = true, working_directory = working_directory);

        if result.exit_code {
            compiler_report(tprint("Compiler failed with exit code '%'.\n", result.exit_code), loc);
            return false;
        }

        if type == .STATIC_LIBRARY {
            // Create library:
            array_reset_keeping_memory(*arguments);

            librarian := join(linker_path, "\\lib.exe");

            array_add(*arguments, librarian, "/nologo");
            array_add(*arguments, ..objs);
            array_add(*arguments, tprint("/OUT:%", output_filename));

            log("%", get_quoted_command_string(arguments));
            result, output_string, error_string := run_command(..arguments, capture_and_return_output = true, print_captured_output = true, working_directory = working_directory);

            if result.exit_code {
                compiler_report(tprint("Librarian failed with exit code '%'.\n", result.exit_code), loc);
                return false;
            }
        }
    } else {
        if #complete type == {
            case .STATIC_LIBRARY;
                output_filename = tprint("%.a", output_basename);
            case .OBJ_FILE;
                output_filename = tprint("%.o", output_basename);
            case .DYNAMIC_LIBRARY;
                if target == {
                    case .IOS;     #through;
                    case .MACOS;   output_filename = tprint("%.dylib", output_basename);

                    case .LINUX;   #through;
                    case .ANDROID; output_filename = tprint("%.so", output_basename);

                    case; assert(false);
                }
            case .EXECUTABLE;
                output_filename = copy_temporary_string(output_basename);
        }

        #if OS == .WINDOWS {
            path_overwrite_separators(output_filename, #char "\\");
        }

        compiler := compiler_executable_path;
        ar := ar_executable_path;
        is_cpp_project := false;
        if !compiler || (type == .STATIC_LIBRARY && !ar) {
            for files {
                if ends_with(it, ".cpp") {
                    is_cpp_project = true; // Use c++ compiler, so we link the required c++ runtime libraries by default.
                    break;
                }
            }

            if target == {
                case .NN_SWITCH; #through;
                case .OUNCE;
                    #if NINTENDO_SUPPORT {
                        nintendo_compiler_path := get_nintendo_compiler_path();
                        if !compiler compiler = tprint("%/bin/%", nintendo_compiler_path, ifx is_cpp_project then "clang++" else "clang");
                        if !ar       ar       = tprint("%/bin/llvm-ar", nintendo_compiler_path);
                    }
                case .PS5;
                    #if PS5_SUPPORT {
                        compiler_path, ar_path := get_ps5_toolchain_paths();
                        if !compiler compiler = compiler_path;
                        if !ar       ar = ar_path;
                    }
                case .ANDROID;
                    ndk := get_ndk_paths();

                    if !compiler compiler = tprint("%/bin/%", ndk.toolchain, ifx is_cpp_project then "clang++" else "clang");
                    if !ar       ar       = tprint("%/bin/llvm-ar", ndk.toolchain);

                case;
                    if !compiler {
                        if is_cpp_project {
                            // @Cleanup: Could be simplified to the following, but that currently triggers a compiler bug. -rluba, 2024-01-23
                            // compiler = ifx to_string(getenv("CXX")) else "clang++";
                            compiler = to_string(getenv("CXX"));
                            if !compiler compiler ="clang++";
                        } else {
                            compiler = to_string(getenv("CC"));
                            if !compiler compiler ="clang";
                        }
                    }

                    if !ar ar = "ar";
            }
        }

        array_add(*arguments, compiler);
        #if NINTENDO_SUPPORT {
            if target == .OUNCE {
                is_asm_project := false;
                for files {
                    if ends_with(it, ".S") {
                        is_asm_project = true; // Use c++ compiler, so we link the required c++ runtime libraries by default.
                        break;
                    }
                }

                if is_asm_project {
                    array_add(*arguments, tprint("--config=%", get_ounce_asm_config_path()));
                } else if is_cpp_project {
                    array_add(*arguments, tprint("--config=%", get_ounce_cxx_config_path()));
                } else {
                    array_add(*arguments, tprint("--config=%", get_ounce_c_config_path()));
                }
            }
        }

        if debug {
            if target == .WASM {
                // There is a bug in clang / LLVM 21 that causes the new @llvm.fake.use intrinsics to not be properly stripped by the WASM backend.
                // This causes it to still emit the loads for the @llvm.fake.use calls, leaving additional elements on the stack.
                // The result is an error like this when trying to load the WASM in node.js 24:
                //
                //     [CompileError: WebAssembly.instantiate(): Compiling function #164:"return_plain_float(float)" failed: expected 1 elements on the stack for fallthru, found 3 @+910168]
                //
                // Compiling with -O0 causes the @llvm.fake.use calls to not show up in the IR. And -O1 or higher optimizes the loads aways, so they don't cause a problem either.
                // We’ll see if this is fixed in LLVM 22+ when it gets released.
                //  -rluba, 2025-10-20
                array_add(*arguments, "-g", "-O1");
            } else {
                array_add(*arguments, "-g", "-Og");
            }
        } else {
            array_add(*arguments, "-O3");
        }

        array_add(*arguments, ..extra);

        if type == .STATIC_LIBRARY || type == .OBJ_FILE {
            array_add(*arguments, "-c");
        } else {
            if type == .DYNAMIC_LIBRARY {
                array_add(*arguments, "-shared", "-fpic");
            }

            if target == .MACOS {
                if type == {
                    case .DYNAMIC_LIBRARY;
                        array_add(*arguments, "-install_name", tprint("@rpath/%", output_filename));
                    case .EXECUTABLE;
                        array_add(*arguments, "-rpath", "@loader_path");
                }
            }

            array_add(*arguments, "-o", output_filename);
        }

        // Add files:
        objs: [..] string;
        array_reserve(*objs, files.count);
        for files {
            src := copy_temporary_string(it);
            path_overwrite_separators(src);
            array_add(*arguments, src);

            array_add(*objs, tprint("%.o", path_basename(it)));
        }

        // Make sure to cleanup the resulting obj files.
        defer {
            if type != .OBJ_FILE {
                for objs file_delete(it);
            }
        }

        array_add(*arguments, .. library_files);

        log("%", get_quoted_command_string(arguments));
        result, output_string, error_string := run_command(..arguments, capture_and_return_output = true, print_captured_output = true, working_directory = working_directory);

        if result.exit_code {
            compiler_report(tprint("Compiler failed with exit code '%'.\n", result.exit_code), loc);
            return false;
        }

        if type == .STATIC_LIBRARY {
            file_delete(output_filename); // ar only adds/updates the archive, but does not delete files from it.

            // Create library:
            array_reset_keeping_memory(*arguments);
            array_add(*arguments,
                ar,
                ifx target == .WASM then "-rcs" else "-rc",   // replace or insert files into the archive, do not warn if archive needs to be created. (+s for WASM to create an archive index)
                output_filename,
            );

            array_add(*arguments, ..objs);

            // Run archiver command:
            log("%", get_quoted_command_string(arguments));
            result, output_string, error_string := run_command(..arguments, capture_and_return_output = true, print_captured_output = true, working_directory = working_directory);

            if result.exit_code {
                compiler_report(tprint("Archive command failed with exit code '%'.\n", result.exit_code), loc);
                return false;
            }
        }
    }

    return true;
}

build_universal_macos_binary :: (lib_path: string, files: ..string, type: Build_Type, debug := false, extra: [] string = .[]) -> bool {
    lib_path_x64   := tprint("%_x64", lib_path);
    lib_path_arm64 := tprint("%_arm64", lib_path);
    MACOS_X64_VERSION_ARG   :: "-mmacos-version-min=10.13"; // Our current x64 min version
    MACOS_ARM64_VERSION_ARG :: "-mmacos-version-min=11.0";  // Earliest version that supports arm64
    // x64 variant
    args: [..] string;
    array_add(*args, ..extra);
    array_add(*args, "-arch", "x86_64", MACOS_X64_VERSION_ARG);
    success := build_cpp(lib_path_x64, ..files, type = type, debug = debug, extra = args);
    // arm64 variant
    args.count -= 3;
    array_add(*args, "-arch", "arm64", MACOS_ARM64_VERSION_ARG);
    success &&= build_cpp(lib_path_arm64, ..files, type = type, debug = debug, extra = args);
    if !success return false;

    // create universal binary
    extension: string;
    if type == {
        case .STATIC_LIBRARY;  extension = ".a";
        case .DYNAMIC_LIBRARY; extension = ".dylib";
    }
    run_result := run_command("lipo", "-create", join(lib_path_x64, extension), join(lib_path_arm64, extension), "-output", join(lib_path, extension));
    return run_result.exit_code == 0;
}


enum_cpp_files :: (path: string, recursive:=false) -> [..] string {
    files: [..] string;

    visitor :: (info: *File_Visit_Info, files: *[..] string) {
        extension := path_extension(info.full_name);
        if extension == "cpp" || extension == "c" {
            array_add(files, copy_string(info.full_name));
        }
    }

    visit_files(path, recursive=recursive, *files, visitor);

    return files;
}

free_cpp_files :: (files: [] string) {
    for files free(it);
    array_free(files);
}

#scope_file

#import "Android/Toolchain";
#import "Basic";
#import "File";
#import "String";
#import "Process";
using,except(Build_Type) Compiler :: #import "Compiler";
#import "File_Utilities";

#if OS == .WINDOWS {
    #import "Windows_Resources";
    #import "Windows";
} else {
    #import "POSIX";
}

#if PS5_SUPPORT {
    #import "ps5/toolchain";
}
#if NINTENDO_SUPPORT {
    #import "Nintendo/Toolchain";
}
