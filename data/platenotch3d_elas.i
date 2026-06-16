#-------------------------------------------------------------------------
# pyvale: gmsh,mechanical,transient
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
#_* MOOSEHERDER VARIABLES - START
!include common_load_time.i
!include common_elas_props.i
simName = notch3d_elas
#** MOOSEHERDER VARIABLES - END
#-------------------------------------------------------------------------

[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
[]

[Mesh]
    type = FileMesh
    file = 'mesh3d_notchplate.msh'
[]

[Physics/SolidMechanics/QuasiStatic]
    [all]
        strain = SMALL
        incremental = true
        add_variables = true
        material_output_family = LAGRANGE   # MONOMIAL, LAGRANGE
        material_output_order = FIRST       # CONSTANT, FIRST, SECOND,
        # generate_output = 'vonmises_stress strain_xx strain_yy strain_zz strain_xy strain_yz strain_xz'
        generate_output = 'vonmises_stress strain_xx strain_yy strain_zz strain_xy strain_yz strain_xz stress_xx stress_yy stress_zz stress_xy stress_yz stress_xz'
    []
[]

[BCs]
    [bottom_x]
        type = DirichletBC
        variable = disp_x
        boundary = 'bc-bot-point-back bc-bot-point-front'
        value = 0.0
    []
    [bottom_y]
        type = DirichletBC
        variable = disp_y
        boundary = 'bc-bot'
        value = 0.0
    []
    [bottom_z]
        type = DirichletBC
        variable = disp_z
        boundary = 'bc-bot-point-back'
        value = 0.0
    []

    [top_y]
        type = FunctionDirichletBC
        variable = disp_y
        boundary = 'bc-top'
        function = '${topDispRate}*t'
    []
[]

[Materials]
    [elasticity]
        type = ComputeIsotropicElasticityTensor
        youngs_modulus = ${EMod}
        poissons_ratio = ${PRatio}
    []
    [stress]
        type = ComputeFiniteStrainElasticStress
    []
[]

!include common_solver.i


[Postprocessors]
    [react_y_top]
        type = SidesetReaction
        direction = '0 1 0'
        stress_tensor = stress
        boundary = 'bc-top'
    []
    [disp_y_max]
        type = NodalExtremeValue
        variable = disp_y
    []
[]

!include common_outputs.i
