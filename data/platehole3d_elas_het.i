#-------------------------------------------------------------------------
# pyvale: gmsh,mechanical,transient
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
#_* MOOSEHERDER VARIABLES - START

timeStep = 1

endTime = 24
maxDisp = 0.02e-3

#endTime = 2
#maxDisp = 1e-3

# Mechanical Loads/BCs
topDispRate = ${fparse maxDisp / endTime}  # m/s

# Plate geometry 
plateWidth = 25.0e-3
plateHeight = 35.0e-3 

# Spatially varying modulus Gaussian parameters
PRatio = 0.3      # -
EModInf = 200e9         # Pa, modulus far from the bump
PeakEMod = 240e9        # Pa, modulus at the bump centre

centX = ${fparse 0.0}           # m
centY = ${fparse plateHeight/2}          # m

stdX = ${fparse plateWidth/2}           # m
stdY = ${fparse plateWidth/4}           # m

#** MOOSEHERDER VARIABLES - END
#-------------------------------------------------------------------------

[GlobalParams]
    displacements = 'disp_x disp_y disp_z'
[]

[Mesh]
    type = FileMesh
    file = 'mesh3d_holeplate.msh'
[]

[Physics/SolidMechanics/QuasiStatic]
    [all]
        strain = SMALL
        incremental = true
        add_variables = true
        material_output_family = LAGRANGE
        material_output_order = FIRST
        generate_output = 'vonmises_stress strain_xx strain_yy strain_zz strain_xy strain_yz strain_xz'
    []
[]

[BCs]
    [bottom_x]
        type = DirichletBC
        variable = disp_x
        boundary = 'bc-bot'
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
        boundary = 'bc-bot'
        value = 0.0
    []

    [top_x]
        type = DirichletBC
        variable = disp_x
        boundary = 'bc-top'
        value = 0.0
    []

    [top_y]
        type = FunctionDirichletBC
        variable = disp_y
        boundary = 'bc-top'
        function = '${topDispRate}*t'
    []

    [top_z]
        type = DirichletBC
        variable = disp_z
        boundary = 'bc-top'
        value = 0.0
    []
[]

[Functions]
    [youngs_modulus_fn]
        type = ParsedFunction
        expression = '${EModInf} + (${PeakEMod} - ${EModInf}) * exp(-0.5 * (((x - ${centX})/${stdX})^2 + ((y - ${centY})/${stdY})^2))'
    []
[]

[Materials]
    [youngs_modulus_material]
        type = GenericFunctionMaterial
        prop_names = 'youngs_modulus'
        prop_values = 'youngs_modulus_fn'
    []

    [poissons_ratio_material]
        type = GenericConstantMaterial
        prop_names = 'poissons_ratio'
        prop_values = '${PRatio}'
    []

    [elasticity]
        type = ComputeVariableIsotropicElasticityTensor
        args = ''
        youngs_modulus = youngs_modulus
        poissons_ratio = poissons_ratio
    []

    [stress]
        type = ComputeFiniteStrainElasticStress
    []
[]

[AuxVariables]
    [youngs_modulus_out]
        family = MONOMIAL
        order = CONSTANT
    []
[]

[AuxKernels]
    [youngs_modulus_out]
        type = MaterialRealAux
        variable = youngs_modulus_out
        property = youngs_modulus
        execute_on = 'INITIAL TIMESTEP_END'
    []
[]

[Preconditioning]
    [SMP]
        type = SMP
        full = true
    []
[]

[Executioner]
    type = Transient

    solve_type = 'NEWTON'
    petsc_options = '-snes_converged_reason'
    petsc_options_iname = '-pc_type -ksp_type -ksp_gmres_restart'
    petsc_options_value = ' lu       gmres     200'

    l_max_its = 100
    l_tol = 1e-6

    nl_max_its = 50
    nl_rel_tol = 1e-6
    nl_abs_tol = 1e-6

    end_time = ${endTime}
    dt = ${timeStep}

    [Predictor]
        type = SimplePredictor
        scale = 1
    []
[]

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

[Outputs]
    exodus = true
    csv = true
    file_base = 'hole3d_elas_het_${endTime}f'
[]
