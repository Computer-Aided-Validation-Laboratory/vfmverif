//==============================================================================
// Gmsh 3D parametric plate mesh with two circular edge notches
// author: Lloyd Fletcher (scepticalrabbit)
//==============================================================================

// Always set to OpenCASCADE - circles and boolean opts are much easier!
SetFactory("OpenCASCADE");

// Allows gmsh to print to terminal in vscode - easier debugging
General.Terminal = 0;

// View options
Geometry.PointLabels = 0;
Geometry.CurveLabels = 0;
Geometry.SurfaceLabels = 0;
Geometry.VolumeLabels = 0;

//------------------------------------------------------------------------------
// Variables

// Geometric variables
plate_width = 25.0e-3;
plate_height = 35.0e-3; // Must be greater than plate width
plate_thick = 1.0e-3;

plate_diff = plate_height-plate_width;

// Notch variables
notch_1_rad = plate_width/4;
notch_1_loc_x = -plate_width/2;
notch_1_loc_y = plate_height/2 + 5.0e-3;

notch_2_rad = plate_width/4;
notch_2_loc_x = plate_width/2;
notch_2_loc_y = plate_height/2 - 5.0e-3;

// Mesh variables
mesh_ref = 2;
mesh_size = 4.0e-3/mesh_ref;

plate_thick_layers = 2;
//file_name = Sprintf("mesh3d_notchplate_%g.msh", mesh_ref);
file_name = "mesh3d_notchplate.msh";

tol = mesh_size/4; // Used for bounding box selection tolerance
tol_thick = plate_thick/4;

second_ord_incomp = 1;
//------------------------------------------------------------------------------
// Geometry Definition

// Split plate into eight pieces following the original convention.
s1 = news;
Rectangle(s1) = {-plate_width/2,0.0,0.0,
                plate_width/2,plate_diff/2};

s2 = news;
Rectangle(s2) = {0.0,0.0,0.0,
                plate_width/2,plate_diff/2};

s3 = news;
Rectangle(s3) = {-plate_width/2,plate_diff/2,0.0,
                plate_width/2,plate_width/2};

s4 = news;
Rectangle(s4) = {0.0,plate_diff/2,0.0,
                plate_width/2,plate_width/2};

s5 = news;
Rectangle(s5) = {-plate_width/2,plate_width/2+plate_diff/2,0.0,
                plate_width/2,plate_width/2};

s6 = news;
Rectangle(s6) = {0.0,plate_width/2+plate_diff/2,0.0,
                plate_width/2,plate_width/2};

s7 = news;
Rectangle(s7) = {-plate_width/2,plate_height-plate_diff/2,0.0,
                plate_width/2,plate_diff/2};

s8 = news;
Rectangle(s8) = {0.0,plate_height-plate_diff/2,0.0,
                plate_width/2,plate_diff/2};

// Merge coincident edges of the overlapping rectangles
BooleanFragments{ Surface{s1}; Delete; }
                { Surface{s2,s3,s4,s5,s6,s7,s8}; Delete; }

// Create notch cutting surfaces
c1 = newc;
Circle(c1) = {notch_1_loc_x,notch_1_loc_y,0.0,notch_1_rad};

cl1 = newcl;
Curve Loop(cl1) = {c1};

sn1 = news;
Plane Surface(sn1) = {cl1};


c2 = newc;
Circle(c2) = {notch_2_loc_x,notch_2_loc_y,0.0,notch_2_rad};

cl2 = newcl;
Curve Loop(cl2) = {c2};

sn2 = news;
Plane Surface(sn2) = {cl2};

// Cut the two circular edge notches out of the full plate.
BooleanDifference{ Surface{:}; Delete; }
                 { Surface{sn1,sn2}; Delete; }

//------------------------------------------------------------------------------
// Mesh sizing

// Global characteristic length
Mesh.CharacteristicLengthMin = mesh_size;
Mesh.CharacteristicLengthMax = mesh_size;

// NO Recombine on surface - use free triangular/tet/prism mesh as requested

// Extrude the 2D geometry into 3D
Extrude{0.0,0.0,plate_thick}{
    Surface{:}; Layers{plate_thick_layers}; 
    // Recombine is only for hexes, remove it if we want triangular facets
}

//------------------------------------------------------------------------------
// Physical volumes and surfaces for export/BCs

Physical Volume("plate-vol") = {Volume{:}};

ps1() = Surface In BoundingBox{
    -plate_width/2-tol,plate_height-tol,0.0-tol,
    plate_width/2+tol,plate_height+tol,plate_thick+tol};
Physical Surface("bc-top") = {ps1()};

ps2() = Surface In BoundingBox{
    -plate_width/2-tol,0.0-tol,0.0-tol,
    plate_width/2+tol,0.0+tol,plate_thick+tol};
Physical Surface("bc-bot") = {ps2()};

ps3() = Surface In BoundingBox{
    -plate_width/2-tol,0.0-tol,plate_thick-tol_thick,
    plate_width/2+tol,plate_height+tol,plate_thick+tol_thick};
Physical Surface("plate-surf-vis-front") = {ps3()};

ps4() = Surface In BoundingBox{
    -plate_width/2-tol,0.0-tol,0.0-tol_thick,
    plate_width/2+tol,plate_height+tol,0.0+tol_thick};
Physical Surface("plate-surf-vis-back") = {ps4()};

//------------------------------------------------------------------------------
// Global meshing
num_threads = 4;

Mesh.Algorithm = 6;
Mesh.Algorithm3D = 10;

General.NumThreads = num_threads;
Mesh.MaxNumThreads1D = num_threads;
Mesh.MaxNumThreads2D = num_threads;
Mesh.MaxNumThreads3D = num_threads;

Mesh.ElementOrder = 2;
Mesh.SecondOrderIncomplete = second_ord_incomp;

Mesh 3;

//------------------------------------------------------------------------------
// Save and exit

Save Str(file_name);
//Exit;
