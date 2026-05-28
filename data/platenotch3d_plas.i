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
Yield = 200e6      # Pa
HardMod = 1000e6   # Pa

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
        strain = FINITE
        incremental = true
        add_variables = true
        use_automatic_differentiation = true

        material_output_family = LAGRANGE
        material_output_order = FIRST

        generate_output = 'vonmises_stress strain_xx strain_yy strain_zz strain_xy strain_yz strain_xz plastic_strain_xx plastic_strain_yy plastic_strain_zz plastic_strain_xy plastic_strain_yz plastic_strain_xz'
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
        yield_stress = ${Yield}
        hardening_constant = ${HardMod}
        relative_tolerance = 1e-9
        absolute_tolerance = 1e-9
    []
[]

[AuxVariables]
    [effective_plastic_strain_out]
        family = MONOMIAL
        order = CONSTANT
    []
[]

[AuxKernels]
    [effective_plastic_strain_out]
        type = ADMaterialRealAux
        variable = effective_plastic_strain_out
        property = effective_plastic_strain
        execute_on = 'INITIAL TIMESTEP_END'
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
    file_base = 'notch3d_plas_${endTime}f'
[]
