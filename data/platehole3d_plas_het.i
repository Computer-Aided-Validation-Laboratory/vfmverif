#-------------------------------------------------------------------------
# pyvale: gmsh,mechanical,transient
#-------------------------------------------------------------------------

#-------------------------------------------------------------------------
#_* MOOSEHERDER VARIABLES - START

timeStep = 1
endTime = 24
maxDisp = 0.05e-3

# Mechanical Loads/BCs
topDispRate = ${fparse maxDisp / endTime}  # m/s

# Mechanical Props: SS316L @ 20degC
EMod = 200e9       # Pa
PRatio = 0.3       # -
HardMod = 1000e6   # Pa

# Plate geometry
plateWidth = 25.0e-3
plateHeight = 35.0e-3

# Spatially varying yield stress Gaussian parameters
YieldInf = 200e6         # Pa, yield stress far from the bump
PeakYield = 240e6        # Pa, yield stress at the bump centre

centX = ${fparse 0.0}                 # m
centY = ${fparse plateHeight / 2}     # m

stdX = ${fparse plateWidth / 2}       # m
stdY = ${fparse plateWidth / 4}       # m

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
        strain = FINITE
        incremental = true
        add_variables = true
        use_automatic_differentiation = true

        material_output_family = LAGRANGE
        material_output_order = FIRST

        generate_output = 'vonmises_stress strain_xx strain_yy strain_zz strain_xy strain_yz strain_xz plastic_strain_xx plastic_strain_yy plastic_strain_zz plastic_strain_xy plastic_strain_yz plastic_strain_xz'
    []
[]

[Functions]
    [yield_stress_fn]
        type = ParsedFunction
        expression = '${YieldInf} + (${PeakYield} - ${YieldInf}) * exp(-0.5 * (((x - ${centX}) / ${stdX})^2 + ((y - ${centY}) / ${stdY})^2))'
    []

    # ADIsotropicPlasticityStressUpdate evaluates yield_stress_function as a
    # function of the coupled "temperature" variable. In that call, t is the
    # coupled scalar value, not the simulation time. So this returns the
    # yield_stress_field value directly.
    [yield_identity_fn]
        type = ParsedFunction
        expression = 't'
    []
[]

[AuxVariables]
    [effective_plastic_strain_out]
        family = MONOMIAL
        order = CONSTANT
    []

    # Static spatial field that is coupled into the plasticity model through
    # the temperature-dependent yield-stress interface.
    [yield_stress_field]
        family = MONOMIAL
        order = CONSTANT
    []

    [yield_stress_out]
        family = MONOMIAL
        order = CONSTANT
    []
[]

[ICs]
    # This is the important bit. It makes sure the plasticity model sees a
    # positive yield stress before any AuxKernel execution ordering can bite us.
    [yield_stress_field_ic]
        type = FunctionIC
        variable = yield_stress_field
        function = yield_stress_fn
    []

    [yield_stress_out_ic]
        type = FunctionIC
        variable = yield_stress_out
        function = yield_stress_fn
    []
[]

[AuxKernels]
    [yield_stress_field]
        type = FunctionAux
        variable = yield_stress_field
        function = yield_stress_fn
        execute_on = 'INITIAL TIMESTEP_BEGIN'
    []

    [effective_plastic_strain_out]
        type = ADMaterialRealAux
        variable = effective_plastic_strain_out
        property = effective_plastic_strain
        execute_on = 'INITIAL TIMESTEP_END'
    []

    [yield_stress_out]
        type = FunctionAux
        variable = yield_stress_out
        function = yield_stress_fn
        execute_on = 'INITIAL TIMESTEP_END'
    []
[]

[Materials]
    [elasticity]
        type = ADComputeIsotropicElasticityTensor
        youngs_modulus = ${EMod}
        poissons_ratio = ${PRatio}
    []

    [radial_return_stress]
        type = ADComputeMultipleInelasticStress
        inelastic_models = 'isoplas'
    []

    [isoplas]
        type = ADIsotropicPlasticityStressUpdate

        # yield_stress itself is a Real/double parameter, so it cannot take
        # a material-property name. Use the temperature-dependent hook instead.
        yield_stress_function = yield_identity_fn
        temperature = yield_stress_field

        hardening_constant = ${HardMod}
        relative_tolerance = 1e-9
        absolute_tolerance = 1e-9
    []
[]

[BCs]
    [bottom_x]
        type = ADDirichletBC
        variable = disp_x
        boundary = 'bc-bot'
        value = 0.0
    []

    [bottom_y]
        type = ADDirichletBC
        variable = disp_y
        boundary = 'bc-bot'
        value = 0.0
    []

    [bottom_z]
        type = ADDirichletBC
        variable = disp_z
        boundary = 'bc-bot'
        value = 0.0
    []

    [top_x]
        type = ADDirichletBC
        variable = disp_x
        boundary = 'bc-top'
        value = 0.0
    []

    [top_y]
        type = ADFunctionDirichletBC
        variable = disp_y
        boundary = 'bc-top'
        function = '${topDispRate}*t'
    []

    [top_z]
        type = ADDirichletBC
        variable = disp_z
        boundary = 'bc-top'
        value = 0.0
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
        type = ADSidesetReaction
        direction = '0 1 0'
        stress_tensor = stress
        boundary = 'bc-top'
    []

    [disp_y_max]
        type = NodalExtremeValue
        variable = disp_y
    []

    [stress_vm_max]
        type = ElementExtremeValue
        variable = vonmises_stress
    []
[]

[Outputs]
    exodus = true
    csv = true
    file_base = 'hole3d_plas_het_${endTime}f'
[]
