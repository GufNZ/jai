// We don't store the Baker code in the Jai repository.
AT_COMPILE_TIME :: true;

// We don't store the Baker code in the Jai repository.
// Copy it manually from the Thekla2 repository or change this path if you want to re-generate the bindings.
SOURCE_PATH :: "src/thekla_baker";
LIB_BASE_NAME :: "thekla_baker";

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        options := get_build_options();
        args := options.compile_time_command_line;
        if !generate_bindings(args, options.minimum_os_version) {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate_bindings(get_command_line_arguments(), #run get_build_options().minimum_os_version) {
            exit(1);
        }
    }
}


generate_bindings :: (args: [] string, minimum_os_version: type_of(Build_Options.minimum_os_version)) -> bool {
    target_x64     := array_find(args, "-x64");
    target_arm     := array_find(args, "-arm64");
    compile        := array_find(args, "-compile");
    compile_debug  := array_find(args, "-debug");

    cpu_target := CPU;
    if target_x64 cpu_target = .X64;
    if target_arm cpu_target = .ARM64;

    #if OS == {
        case .WINDOWS;
            lib_directory := "windows";
        case .LINUX;
            lib_directory := "linux";
        case .MACOS;
            lib_directory := "macos";
        case;
            #assert false;
    }

    if compile {
        source_files := string.[
            tprint("%/hemicube.cpp",                                        SOURCE_PATH),
            tprint("%/hemicube_integrator.cpp",                             SOURCE_PATH),
            tprint("%/irradiance_cache.cpp",                                SOURCE_PATH),
            tprint("%/irradiance_octree.cpp",                               SOURCE_PATH),
            tprint("%/lightmap_rasterizer.cpp",                             SOURCE_PATH),
            tprint("%/thekla_baker.cpp",                                    SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvcore/Debug.cpp",           SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvcore/RadixSort.cpp",       SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvcore/StrLib.cpp",          SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvimage/BitMap.cpp",         SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvimage/Filter.cpp",         SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvimage/FloatImage.cpp",     SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvimage/HoleFilling.cpp",    SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvimage/Image.cpp",          SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvmath/Basis.cpp",           SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvmath/Box.cpp",             SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvmath/Gamma.cpp",           SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvmath/Half.cpp",            SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvmath/Random.cpp",          SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvmesh/raster/Raster.cpp",   SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/Event.cpp",         SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/Mutex.cpp",         SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/ParallelFor.cpp",   SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/TaskScheduler.cpp", SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/Thread.cpp",        SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/ThreadPool.cpp",    SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/WorkerThread.cpp",  SOURCE_PATH),
            tprint("%/../nvidia-mesh-tools/src/nvthread/nvthread.cpp",      SOURCE_PATH),
        ];
        include_paths := string.[
            "../nvidia-mesh-tools/src/nvmesh",
            "../nvidia-mesh-tools/src",
            "../nvidia-mesh-tools/extern/poshlib",
            "../nvidia-mesh-tools/extern/stb",
        ];

        extra_args: [..] string;
        array_add(*extra_args,
            "-DTHEKLA_BAKER_SHARED",
            "-DTHEKLA_BAKER_EXPORTS",
            "-DNV_OS_OSX_NO_WRITE_CRASH_FILE",
            "-DNV_NO_IMAGEIO",
        );
        #if OS == .WINDOWS {
            for include_paths {
                array_add(*extra_args, tprint("/I%/%", SOURCE_PATH, it));
            }
        } else {
            array_add(*extra_args, "-std=c++11");
            for include_paths {
                array_add(*extra_args, tprint("-I%/%", SOURCE_PATH, it));
            }
        }

        make_directory_if_it_does_not_exist(lib_directory, recursive = true);
        lib_path := tprint("%/%", lib_directory, LIB_BASE_NAME);
        success := true;
        #if OS == {
            case .WINDOWS;
                success = build_cpp_dynamic_lib(lib_path, ..source_files, debug = compile_debug, extra = extra_args, library_files = .["User32.lib"]);
            case .LINUX;
                success = build_cpp_dynamic_lib(lib_path, ..source_files, debug = compile_debug, extra = extra_args, library_files = .["-lpthread"]);
            case .MACOS;
                lib_path_x64   := tprint("%_x64", lib_path);
                lib_path_arm64 := tprint("%_arm64", lib_path);
                macos_x64_version_arg   := "-mmacos-version-min=10.13"; // Our current x64 min version
                macos_arm64_version_arg := "-mmacos-version-min=11.0";  // Earliest version that supports arm64
                // x64 variant
                extra_args_x64: [..] string;
                array_add(*extra_args_x64, ..extra_args);
                array_add(*extra_args_x64, "-arch", "x86_64", macos_x64_version_arg);
                success &&= build_cpp_dynamic_lib(lib_path_x64,   ..source_files, extra = extra_args_x64,   debug=compile_debug);
                // arm64 variant
                extra_args_arm64: [..] string;
                array_add(*extra_args_arm64, ..extra_args);
                array_add(*extra_args_arm64, "-arch", "arm64", macos_arm64_version_arg);
                success &&= build_cpp_dynamic_lib(lib_path_arm64, ..source_files, extra = extra_args_arm64, debug=compile_debug);
                // create universal binaries
                run_result := run_command("lipo", "-create", tprint("%.dylib", lib_path_x64), tprint("%.dylib", lib_path_arm64), "-output", tprint("%.dylib", lib_path));
                success &&= (run_result.exit_code == 0);
        }

        if !success     return false;
    }

    options: Generate_Bindings_Options;
    options.cpu = cpu_target;
    output_filename: string;
    {
        using options;
        if OS == {
            case .WINDOWS;
                output_filename = "windows.jai";
                generate_library_declarations = true;
            case .LINUX; #through;
            case .MACOS;
                output_filename = "unix.jai";
                generate_library_declarations = false;
                footer = tprint(UNIX_FOOTER_TEMPLATE, LIB_BASE_NAME);
            case;
                assert(false);
        }

        array_add(*library_search_paths,  lib_directory);
        array_add(*libraries,             .{filename=LIB_BASE_NAME});
        array_add(*include_paths,         SOURCE_PATH);
        array_add(*source_files,          tprint("%/thekla_baker.h", SOURCE_PATH));
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN");

        array_add(*flatten_namespaces, "Thekla");

        auto_detect_enum_prefixes = true;
        log_stripped_declarations = false;
        generate_compile_time_struct_checks = false;

        // Set up types we want to use to replace float arrays
        vector3 := New(Struct);
        vector3.name = "Vector3";
        vector3.output_name = "Vector3";
        type_of_vector3 := New(CType);
        type_of_vector3.type_of_struct = vector3;
        type_of_vector3.size = size_of(Vector3);

        matrix4 := New(Struct);
        matrix4.name = "Matrix4";
        matrix4.output_name = "Matrix4";
        type_of_matrix4 := New(CType);
        type_of_matrix4.type_of_struct = matrix4;
        type_of_matrix4.size = size_of(Matrix4);

        visitor_data.type_of_vector3 = type_of_vector3;
        visitor_data.type_of_matrix4 = type_of_matrix4;

        visitor = baker_visitor;
    }

    return generate_bindings(options, output_filename);
}

Visitor_Data :: struct {
    type_of_vector3: *CType;
    type_of_matrix4: *CType;
}
visitor_data: Visitor_Data;

baker_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    using visitor_data;

    if decl.kind == .DECLARATION {
        type_ptr := *decl.type;
        while (<<type_ptr).pointer_to {
            type_ptr = *(<<type_ptr).pointer_to;
        }

        if (<<type_ptr).array_element_type == context.generator.type_def_float32 {
            if (<<type_ptr).array_element_count == 3 {
                // replace "[3] float" with "Vector3"
                <<type_ptr = type_of_vector3;
            } else if (<<type_ptr).array_element_count == 16 {
                // replace "[16] float" with "Matrix4"
                <<type_ptr = type_of_matrix4;
            }
        }
    }

    return .RECURSE;
}

UNIX_FOOTER_TEMPLATE :: #string END

#if OS == .LINUX {
    %1 :: #library "linux/%1";
} else #if OS == .MACOS {
    %1 :: #library "macos/%1";
} else {
    #assert false;
}

END

#import "Basic";
#import "Bindings_Generator";
#import "BuildCpp";
#import "Compiler";
#import "File";
#import "Math";
#import "Process";
#import "String";
