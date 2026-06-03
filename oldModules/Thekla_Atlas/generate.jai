AT_COMPILE_TIME :: true;

// We don't store the Atlas code in the Jai repository.
// Copy it manually from the thekla_atlas repository or change this path if you want to re-generate the bindings.
SOURCE_PATH :: "src/thekla_atlas";
LIB_BASE_NAME :: "thekla_atlas";

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
    if target_x64     cpu_target = .X64;
    if target_arm     cpu_target = .ARM64;

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
            tprint("%/src/thekla/thekla_atlas.cpp", SOURCE_PATH),
            // @Cleanup: This compiles but we can probably weed out some of these files:
            tprint("%/src/nvimage/Image.cpp", SOURCE_PATH),
            tprint("%/src/nvimage/BitMap.cpp", SOURCE_PATH),
            // tprint("%/src/nvmesh/weld/Snap.cpp", SOURCE_PATH),
            // tprint("%/src/nvmesh/weld/VertexWeld.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/MeshTopology.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/MeshBuilder.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/Util.cpp", SOURCE_PATH),
            // tprint("%/src/nvmesh/param/BoundaryMap.cpp", SOURCE_PATH),
            // tprint("%/src/nvmesh/param/ConformalMap.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/Atlas.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/AtlasPacker.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/AtlasBuilder.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/LeastSquaresConformalMap.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/OrthogonalProjectionMap.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/ParameterizationQuality.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/param/SingleFaceMap.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/halfedge/Mesh.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/halfedge/Face.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/halfedge/Vertex.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/halfedge/Edge.cpp", SOURCE_PATH),
            // tprint("%/src/nvmesh/BaseMesh.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/geometry/Measurements.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/geometry/Bounds.cpp", SOURCE_PATH),
            // tprint("%/src/nvmesh/QuadTriMesh.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/export/MeshExportOBJ.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/raster/Raster.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/nvmesh.cpp", SOURCE_PATH),
            tprint("%/src/nvmesh/TriMesh.cpp", SOURCE_PATH),
            // tprint("%/src/nvcore/Memory.cpp", SOURCE_PATH),
            tprint("%/src/nvcore/TextWriter.cpp", SOURCE_PATH),
            tprint("%/src/nvcore/RadixSort.cpp", SOURCE_PATH),
            tprint("%/src/nvcore/StrLib.cpp", SOURCE_PATH),
            tprint("%/src/nvcore/FileSystem.cpp", SOURCE_PATH),
            tprint("%/src/nvcore/Debug.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/TypeSerialization.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Basis.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Box.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Random.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Fitting.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Vector.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Matrix.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/ConvexHull.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Sphere.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/ProximityGrid.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Plane.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Solver.cpp", SOURCE_PATH),
            tprint("%/src/nvmath/Sparse.cpp", SOURCE_PATH),
        ];
        include_paths := string.[
            "src",
            "src/nvmesh",
            "extern/poshlib",
            "extern/tinyobj",
        ];
        extra_args: [..] string;
        array_add(*extra_args, "-DTHEKLA_ATLAS_SHARED", "-DTHEKLA_ATLAS_EXPORTS");
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
                success = build_cpp_dynamic_lib(lib_path, ..source_files, debug = compile_debug, extra = extra_args);
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
        array_add(*include_paths,         tprint("%/src", SOURCE_PATH));
        array_add(*source_files,          tprint("%/src/thekla/thekla_atlas.h", SOURCE_PATH));
        array_add(*extra_clang_arguments, "-x", "c++", "-DWIN32_LEAN_AND_MEAN");

        array_add(*flatten_namespaces, "Thekla");

        auto_detect_enum_prefixes           = true;
        alias_original_enum_names           = false;
        log_stripped_declarations           = true;
        generate_compile_time_struct_checks = true;

        // Set up types we want to use to replace float arrays
        vector2 := New(Struct);
        vector2.name = "Vector2";
        vector2.output_name = "Vector2";
        type_of_vector2 := New(CType);
        type_of_vector2.type_of_struct = vector2;
        type_of_vector2.size = size_of(Vector2);

        vector3 := New(Struct);
        vector3.name = "Vector3";
        vector3.output_name = "Vector3";
        type_of_vector3 := New(CType);
        type_of_vector3.type_of_struct = vector3;
        type_of_vector3.size = size_of(Vector3);

        visitor_data.type_of_vector2 = type_of_vector2;
        visitor_data.type_of_vector3 = type_of_vector3;
        visitor = atlas_visitor;
    }

    return generate_bindings(options, output_filename);
}

Visitor_Data :: struct {
    type_of_vector2: *CType;
    type_of_vector3: *CType;
}
visitor_data: Visitor_Data;

atlas_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
    if decl.kind == .DECLARATION {
        type_ptr := *decl.type;
        while (<<type_ptr).pointer_to {
            type_ptr = *(<<type_ptr).pointer_to;
        }

        if (<<type_ptr).array_element_type == context.generator.type_def_float32 {
            if (<<type_ptr).array_element_count == 2 {
                // replace "[2] float" with "Vector2"
                <<type_ptr = visitor_data.type_of_vector2;
            } else if (<<type_ptr).array_element_count == 3 {
                // replace "[3] float" with "Vector3"
                <<type_ptr = visitor_data.type_of_vector3;
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
#import "Process";
#import "String";
#import "Math";
