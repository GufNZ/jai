//
// This file was auto-generated using the following command:
//
// jai modules/Thekla_Baker/generate.jai
//


// Thekla Baker

Baker_Sampling_Mode :: enum s32 {
    Fragment_Sampling          :: 0;
    Vertex_Sampling_Randomized :: 1;
    Vertex_Sampling_Uniform    :: 2;
}

// @@ Add flags for double sided, bent normals, occlusion only, etc.
Baker_Input_Info :: struct {
    index_first:     s32;
    index_count:     s32;
    sampling_mode:   Baker_Sampling_Mode;
    sampling_factor: float; // For vertex sampling only. Set to 0 to sample vertices only.
}

Baker_Input_Mesh :: struct {
    vertex_count:    s32;
    position_stride: s32;
    normal_stride:   s32;
    uv_stride:       s32;
    position_ptr:    *float;
    normal_ptr:      *float;
    uv_ptr:          *float;

    index_count:     s32;
    index_array:     *u32;

    info_count:      s32;
    info_array:      *Baker_Input_Info;

    lightmap_width:  s32;
    lightmap_height: s32;
    mesh_hash:       s32; // Hash to store in the lightmap to match against the mesh data.
}

Baker_Input_Points :: struct {
    vertex_count:    s32;
    position_ptr:    *float;
    position_stride: s32;
    normal_ptr:      *float;
    normal_stride:   s32;
    uv_ptr:          *float;
    uv_stride:       s32;
}

Baker_Input_Transform :: struct {
    obj_to_world:        Matrix4;
    obj_to_world_normal: Matrix4;
}

Baker_Frame :: struct {
    // @@ We could add information about how to render the hemicube in the texture atlas. Viewport rectangle? It's kind of redundant though. Better, request the viewport for each face given an index.
    position: Vector3;
    normal:   Vector3;
    tangent:  Vector3;
}

Baker_Lightmap :: struct {
    width:   s32;
    height:  s32;

    data:    *void = null; // w*h*(4 halfs)

    data_l0: *void = null; // w*h*(4 halfs)
    data_l1: [3] *void; // 3 textures of w*h*(3 u8)
}

Baker_Options :: struct {
    // Render options:
    atlas_width:                      s32 = 1024;
    atlas_height:                     s32 = 1024;
    atlas_count:                      s32 = 2; // Ping-pong between just two pages. Set to 1 to disable.

    // Quality options:
    hemicube_size:                    s32 = 32;
    quality_factor:                   float;
    sampling_distance:                float;
    smoothing_factor:                 float;

    // Occlusion map options:
    output_occlusion_map              := false;
    max_occlusion_distance:           float = 1.0;
    occlusion_power:                  float = 2.0;
    add_floor_plane                   := false;

    Output_Type :: enum s32 {
        NON_DIRECTIONAL_LIGHTMAP :: 0;
        DIRECTIONAL_LIGHTMAP     :: 1;
        OCCLUSION_MAP            :: 2;
    }

    output_type:                      Output_Type = .NON_DIRECTIONAL_LIGHTMAP;

    super_sampling                    := true;
    subpixel_sampling                 := false;
    generate_edge_samples             := true;
    post_process_lightmap             := true; // This does edge filtering.
    compress_lightmap                 := false; // DXT or ETC compression. There's no asset processor in sokoban, so we may want to do this here instead.

    // Debug/Development options:
    use_cache                         := true;
    enable_neighbor_clamping          := false; // @@ Not implemented yet?
    random_rotation                   := true;
    random_seed:                      u32 = 0;

    // @ZG Ignores the horizon_cos of a sample to 0, which results in all samples being considered, regardless of how close they are
    /*
    01/10/2023 I'm going write a very detailed description of what this affects below. I will confirm these as soon as I add the radius display for samples
    I believe this affects the radius of how close samples gets, but its hard to confirm by stepping through the code. I'll return to this comment then.
    
    As of writing I have not found a case where it makes a noticible difference, but we're having it as an option while experimenting with the baker.
    
    The horizontal cosine of the tangent plane is used in Hemicube_Integrator::integrate, where we set the minimum depth of the sample. When the samples are
    close to the tangent plane the depth is left at FLT_MAX, otherwise we calculate a value.
    
    The depth_min value becomes max_dist in Irradiance_Cache::insert. Then we use it to initalize two values in the sample gradient_dist and radius.
    I haven't been able to find a case where gradient_dist is used, so for the time being I'm going to ignore it for this description. What is important here
    is that we clamp the value of max_dist between min_dist and max_dist which are as far as I can tell hardcoded to be 0.05 and 4. (?)
    
    The radius comes into play in Irradiance_Octree::add where the radius is used to figure out where to insert the new node.
    
    All of this is me laying out what I've found to say that it seems like this radius is capped between 0.05 and 4. These values define the min and max distances between samples.
    */
    ignore_tangent_threshold          := false;

    //@ZG When this is true Fragment_Flag_Bent_Normal will be set, allowing for normals to differ considerably from the face normal
    //See Raster_State::add_sample.
    disable_sample_normal_correction  := false;

    // Callbacks: Note this are invoked from the baker thread.
    render_hemicubes:                 #type (atlas_idx: s32, frame_array: *Baker_Frame, frame_count: s32) -> void #c_call;
    read_hemicubes:                   #type (atlas_idx: s32, data: *void) -> void #c_call;
    save_lightmap:                    #type (lightmap: *Baker_Lightmap) -> void #c_call;
    debug_sample:                     #type (atlas_idx: s32, sample: s32, confidence: float, color: *[3] float, radius: float) -> void #c_call;
}

// @@ Add callback for memory allocation, thread creation, etc.
Log_Print :: #type (unknown0: *u8) -> void #c_call;

baker_init :: (printer: Log_Print) -> void #foreign thekla_baker "?baker_init@Thekla@@YAXP6AXPEBD@Z@Z";
baker_shut :: () -> void #foreign thekla_baker "?baker_shut@Thekla@@YAXXZ";

// It would be nice to be able to share the cache between multiple meshes. This could result in improved performance and reduced discontinuitites, but increased memory use.
//typedef void Baker_Cache;   // Opaque struct.
//Baker_Cache * baker_create_cache(const Baker_Input_Mesh* input, const Baker_Input_Transform* xform);
//void baker_start(const Baker_Cache* cache, const Baker_Input_Mesh* input, const Baker_Input_Transform* xform, const Baker_Options* options);
baker_start :: (input: *Baker_Input_Mesh, xform: *Baker_Input_Transform, options: *Baker_Options) -> void #foreign thekla_baker "?baker_start@Thekla@@YAXPEBUBaker_Input_Mesh@1@PEBUBaker_Input_Transform@1@PEBUBaker_Options@1@@Z";
baker_get_total_number_of_samples :: (inputs: *Baker_Input_Mesh, options: *Baker_Options, num_meshes: s32, total_number_of_samples: *s32) -> void #foreign thekla_baker "?baker_get_total_number_of_samples@Thekla@@YAXPEAUBaker_Input_Mesh@1@PEAUBaker_Options@1@HPEAH@Z";

//THEKLA_BAKER_API void baker_start(const Baker_Input_Points* input, const Baker_Input_Transform* xform, const Baker_Options* options);
baker_get_hemicube_viewport :: (idx: s32, face: s32, viewport: *[4] s32) -> void #foreign thekla_baker "?baker_get_hemicube_viewport@Thekla@@YAXHHQEAH@Z";

baker_render_done :: (atlas_idx: s32) -> void #foreign thekla_baker "?baker_render_done@Thekla@@YAXH@Z";
baker_progress :: () -> float #foreign thekla_baker "?baker_progress@Thekla@@YAMXZ";
baker_get_current_mesh_sample_count :: () -> s32 #foreign thekla_baker "?baker_get_current_mesh_sample_count@Thekla@@YAHXZ";

#scope_file

thekla_baker :: #library "windows/thekla_baker";
