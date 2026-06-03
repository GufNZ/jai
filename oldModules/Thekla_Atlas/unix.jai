//
// This file was auto-generated using the following command:
//
// jai modules/Thekla_Atlas/generate.jai
//



Atlas_Charter :: enum u32 {
    Witness :: 0;
    Extract :: 1;
    Default :: 0;
}

Atlas_Mapper :: enum u32 {
    LSCM    :: 0;
    Default :: 0;
}

Atlas_Packer :: enum u32 {
    Witness :: 0;
    Default :: 0;
}

Atlas_Options :: struct {
    mesh_options:    struct {
        fix_nonmanifold_meshes: bool;
    };

    charter:         Atlas_Charter;
    charter_options: union {
        witness: struct {
            proxy_fit_metric_weight:    float;
            roundness_metric_weight:    float;
            straightness_metric_weight: float;
            normal_seam_metric_weight:  float;
            texture_seam_metric_weight: float;
            max_chart_area:             float;
            max_boundary_length:        float;
        };

        extract: struct {
            __empty_struct_padding: u8; // C++ makes empty structs have length 1
        };
    };

    mapper:          Atlas_Mapper;
    mapper_options:  struct {
        preserve_uvs:      bool;
        preserve_boundary: bool;
    };

    packer:          Atlas_Packer;
    packer_options:  union {
        witness: struct {
            packing_quality: s32;
            texels_per_unit: float; // Unit to texel scale. e.g. a 1x1 quad with texelsPerUnit of 32 will take up approximately 32x32 texels in the atlas.
            block_align:     bool; // Align charts to 4x4 blocks.
            conservative:    bool; // Pack charts with extra padding.
        };
    };
}

Atlas_Input_Vertex :: struct {
    position:      Vector3;
    normal:        Vector3;
    uv:            Vector2;
    first_colocal: s32;
}

Atlas_Input_Face :: struct {
    vertex_index:   [3] s32;
    material_index: s32;
}

Atlas_Input_Mesh :: struct {
    vertex_count: s32;
    face_count:   s32;
    vertex_array: *Atlas_Input_Vertex;
    face_array:   *Atlas_Input_Face;
}

Atlas_Output_Vertex :: struct {
    uv:   Vector2;
    xref: s32; // Index of input vertex from which this output vertex originated.
}

Atlas_Output_Mesh :: struct {
    atlas_width:  s32;
    atlas_height: s32;
    vertex_count: s32;
    index_count:  s32;
    vertex_array: *Atlas_Output_Vertex;
    index_array:  *s32;
}

Atlas_Error :: enum u32 {
    Success                   :: 0;
    Invalid_Args              :: 1;
    Invalid_Options           :: 2;
    Invalid_Mesh              :: 3;
    Invalid_Mesh_Non_Manifold :: 4;
    Chart_Failure             :: 5;
    Parameterization_Failure  :: 6;
    Not_Implemented           :: 7;
}

Atlas_Error_Subtype :: enum u32 {
    Duplicate_Edge_Or_Face :: 0;
    None                   :: 1;
}

Atlas_Error_Data :: struct {
    error_subtype: Atlas_Error_Subtype;
    index_count:   s32;
    index_array:   *s32; //For now just face vertex indices
}

Atlas_Message_Callback :: #type (msg: *u8, _context: *void) -> void #c_call;
atlas_set_message_callback :: (callback: Atlas_Message_Callback, _context: *void) -> void #foreign thekla_atlas "_ZN6Thekla26atlas_set_message_callbackEPFvPKcPvES2_";

Atlas_Assert_Callback :: #type (exp: *u8, file: *u8, line: s32, func: *u8, msg: *u8, _context: *void) -> void #c_call;
atlas_set_assert_callback :: (callback: Atlas_Assert_Callback, _context: *void) -> void #foreign thekla_atlas "_ZN6Thekla25atlas_set_assert_callbackEPFvPKcS1_iS1_S1_PvES2_";

atlas_set_default_options :: (options: *Atlas_Options) -> void #foreign thekla_atlas "_ZN6Thekla25atlas_set_default_optionsEPNS_13Atlas_OptionsE";

atlas_generate :: (input: *Atlas_Input_Mesh, options: *Atlas_Options, error: *Atlas_Error, error_data: **Atlas_Error_Data) -> *Atlas_Output_Mesh #foreign thekla_atlas "_ZN6Thekla14atlas_generateEPKNS_16Atlas_Input_MeshEPKNS_13Atlas_OptionsEPNS_11Atlas_ErrorEPPNS_16Atlas_Error_DataE";

atlas_free :: (output: *Atlas_Output_Mesh) -> void #foreign thekla_atlas "_ZN6Thekla10atlas_freeEPNS_17Atlas_Output_MeshE";
atlas_free :: (output: *Atlas_Error_Data) -> void #foreign thekla_atlas "_ZN6Thekla10atlas_freeEPNS_16Atlas_Error_DataE";

#scope_file

#import "Basic"; // For assert


#run {
    {
        info := type_info(Atlas_Options);
        for info.members {
            if it.name == {
                case "mesh_options";
                    assert(it.offset_in_bytes == 0, "Atlas_Options.mesh_options has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 1, "Atlas_Options.mesh_options has unexpected size % instead of 1", it.type.runtime_size);
                case "charter";
                    assert(it.offset_in_bytes == 4, "Atlas_Options.charter has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Options.charter has unexpected size % instead of 4", it.type.runtime_size);
                case "charter_options";
                    assert(it.offset_in_bytes == 8, "Atlas_Options.charter_options has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 28, "Atlas_Options.charter_options has unexpected size % instead of 28", it.type.runtime_size);
                case "mapper";
                    assert(it.offset_in_bytes == 36, "Atlas_Options.mapper has unexpected offset % instead of 36", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Options.mapper has unexpected size % instead of 4", it.type.runtime_size);
                case "mapper_options";
                    assert(it.offset_in_bytes == 40, "Atlas_Options.mapper_options has unexpected offset % instead of 40", it.offset_in_bytes);
                    assert(it.type.runtime_size == 2, "Atlas_Options.mapper_options has unexpected size % instead of 2", it.type.runtime_size);
                case "packer";
                    assert(it.offset_in_bytes == 44, "Atlas_Options.packer has unexpected offset % instead of 44", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Options.packer has unexpected size % instead of 4", it.type.runtime_size);
                case "packer_options";
                    assert(it.offset_in_bytes == 48, "Atlas_Options.packer_options has unexpected offset % instead of 48", it.offset_in_bytes);
                    assert(it.type.runtime_size == 12, "Atlas_Options.packer_options has unexpected size % instead of 12", it.type.runtime_size);
            }
        }
        assert(size_of(Atlas_Options) == 60, "Atlas_Options has size % instead of 60", size_of(Atlas_Options));
    }

    {
        info := type_info(Atlas_Input_Vertex);
        for info.members {
            if it.name == {
                case "position";
                    assert(it.offset_in_bytes == 0, "Atlas_Input_Vertex.position has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 12, "Atlas_Input_Vertex.position has unexpected size % instead of 12", it.type.runtime_size);
                case "normal";
                    assert(it.offset_in_bytes == 12, "Atlas_Input_Vertex.normal has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 12, "Atlas_Input_Vertex.normal has unexpected size % instead of 12", it.type.runtime_size);
                case "uv";
                    assert(it.offset_in_bytes == 24, "Atlas_Input_Vertex.uv has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Atlas_Input_Vertex.uv has unexpected size % instead of 8", it.type.runtime_size);
                case "first_colocal";
                    assert(it.offset_in_bytes == 32, "Atlas_Input_Vertex.first_colocal has unexpected offset % instead of 32", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Input_Vertex.first_colocal has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(Atlas_Input_Vertex) == 36, "Atlas_Input_Vertex has size % instead of 36", size_of(Atlas_Input_Vertex));
    }

    {
        info := type_info(Atlas_Input_Face);
        for info.members {
            if it.name == {
                case "vertex_index";
                    assert(it.offset_in_bytes == 0, "Atlas_Input_Face.vertex_index has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 12, "Atlas_Input_Face.vertex_index has unexpected size % instead of 12", it.type.runtime_size);
                case "material_index";
                    assert(it.offset_in_bytes == 12, "Atlas_Input_Face.material_index has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Input_Face.material_index has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(Atlas_Input_Face) == 16, "Atlas_Input_Face has size % instead of 16", size_of(Atlas_Input_Face));
    }

    {
        info := type_info(Atlas_Input_Mesh);
        for info.members {
            if it.name == {
                case "vertex_count";
                    assert(it.offset_in_bytes == 0, "Atlas_Input_Mesh.vertex_count has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Input_Mesh.vertex_count has unexpected size % instead of 4", it.type.runtime_size);
                case "face_count";
                    assert(it.offset_in_bytes == 4, "Atlas_Input_Mesh.face_count has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Input_Mesh.face_count has unexpected size % instead of 4", it.type.runtime_size);
                case "vertex_array";
                    assert(it.offset_in_bytes == 8, "Atlas_Input_Mesh.vertex_array has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Atlas_Input_Mesh.vertex_array has unexpected size % instead of 8", it.type.runtime_size);
                case "face_array";
                    assert(it.offset_in_bytes == 16, "Atlas_Input_Mesh.face_array has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Atlas_Input_Mesh.face_array has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(Atlas_Input_Mesh) == 24, "Atlas_Input_Mesh has size % instead of 24", size_of(Atlas_Input_Mesh));
    }

    {
        info := type_info(Atlas_Output_Vertex);
        for info.members {
            if it.name == {
                case "uv";
                    assert(it.offset_in_bytes == 0, "Atlas_Output_Vertex.uv has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Atlas_Output_Vertex.uv has unexpected size % instead of 8", it.type.runtime_size);
                case "xref";
                    assert(it.offset_in_bytes == 8, "Atlas_Output_Vertex.xref has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Output_Vertex.xref has unexpected size % instead of 4", it.type.runtime_size);
            }
        }
        assert(size_of(Atlas_Output_Vertex) == 12, "Atlas_Output_Vertex has size % instead of 12", size_of(Atlas_Output_Vertex));
    }

    {
        info := type_info(Atlas_Output_Mesh);
        for info.members {
            if it.name == {
                case "atlas_width";
                    assert(it.offset_in_bytes == 0, "Atlas_Output_Mesh.atlas_width has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Output_Mesh.atlas_width has unexpected size % instead of 4", it.type.runtime_size);
                case "atlas_height";
                    assert(it.offset_in_bytes == 4, "Atlas_Output_Mesh.atlas_height has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Output_Mesh.atlas_height has unexpected size % instead of 4", it.type.runtime_size);
                case "vertex_count";
                    assert(it.offset_in_bytes == 8, "Atlas_Output_Mesh.vertex_count has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Output_Mesh.vertex_count has unexpected size % instead of 4", it.type.runtime_size);
                case "index_count";
                    assert(it.offset_in_bytes == 12, "Atlas_Output_Mesh.index_count has unexpected offset % instead of 12", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Output_Mesh.index_count has unexpected size % instead of 4", it.type.runtime_size);
                case "vertex_array";
                    assert(it.offset_in_bytes == 16, "Atlas_Output_Mesh.vertex_array has unexpected offset % instead of 16", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Atlas_Output_Mesh.vertex_array has unexpected size % instead of 8", it.type.runtime_size);
                case "index_array";
                    assert(it.offset_in_bytes == 24, "Atlas_Output_Mesh.index_array has unexpected offset % instead of 24", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Atlas_Output_Mesh.index_array has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(Atlas_Output_Mesh) == 32, "Atlas_Output_Mesh has size % instead of 32", size_of(Atlas_Output_Mesh));
    }

    {
        info := type_info(Atlas_Error_Data);
        for info.members {
            if it.name == {
                case "error_subtype";
                    assert(it.offset_in_bytes == 0, "Atlas_Error_Data.error_subtype has unexpected offset % instead of 0", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Error_Data.error_subtype has unexpected size % instead of 4", it.type.runtime_size);
                case "index_count";
                    assert(it.offset_in_bytes == 4, "Atlas_Error_Data.index_count has unexpected offset % instead of 4", it.offset_in_bytes);
                    assert(it.type.runtime_size == 4, "Atlas_Error_Data.index_count has unexpected size % instead of 4", it.type.runtime_size);
                case "index_array";
                    assert(it.offset_in_bytes == 8, "Atlas_Error_Data.index_array has unexpected offset % instead of 8", it.offset_in_bytes);
                    assert(it.type.runtime_size == 8, "Atlas_Error_Data.index_array has unexpected size % instead of 8", it.type.runtime_size);
            }
        }
        assert(size_of(Atlas_Error_Data) == 16, "Atlas_Error_Data has size % instead of 16", size_of(Atlas_Error_Data));
    }
}


#if OS == .LINUX {
    thekla_atlas :: #library "linux/thekla_atlas";
} else #if OS == .MACOS {
    thekla_atlas :: #library "macos/thekla_atlas";
} else {
    #assert false;
}

