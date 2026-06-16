import re
from pathlib import Path


def get_sim_name(filename: str) -> str:
    # e.g., platehole3d_elas.i -> hole3d_elas
    name = filename.replace("plate", "")
    name = name.replace(".i", "")
    return name


def refactor_file(file_path: Path) -> None:
    content = file_path.read_text()
    name = file_path.name
    sim_name = get_sim_name(name)

    if "elas_het" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_het_geometry.i\n"
            f"simName = {sim_name}\n"
            "PRatio = 0.3      # -\n"
            "EModInf = 200e9         "
            "# Pa, modulus far from the bump\n"
            "PeakEMod = 240e9        "
            "# Pa, modulus at the bump centre\n"
            "#** MOOSEHERDER VARIABLES - END"
        )
    elif "plas_het" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_het_geometry.i\n"
            f"simName = {sim_name}\n"
            "EMod = 200e9       # Pa\n"
            "PRatio = 0.3       # -\n"
            "HardMod = 1000e6   # Pa\n"
            "YieldInf = 200e6         "
            "# Pa, yield stress far from the bump\n"
            "PeakYield = 240e6        "
            "# Pa, yield stress at the bump centre\n"
            "#** MOOSEHERDER VARIABLES - END"
        )
    elif "elas" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_elas_props.i\n"
            f"simName = {sim_name}\n"
            "#** MOOSEHERDER VARIABLES - END"
        )
    elif "plas" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_plas_props.i\n"
            f"simName = {sim_name}\n"
            "#** MOOSEHERDER VARIABLES - END"
        )
    else:
        var_replacement = ""

    # Locate and replace variables block
    pattern_var = (
        r"#_\* MOOSEHERDER VARIABLES - START[\s\S]*?"
        r"#\*\* MOOSEHERDER VARIABLES - END"
    )
    content = re.sub(pattern_var, var_replacement, content)

    # Replace solver blocks with include
    pattern_solver = (
        r"\[Preconditioning\][\s\S]*?\[Executioner\]"
        r"[\s\S]*?\[Predictor\][\s\S]*?\[\]\s*\[\]"
    )
    content = re.sub(pattern_solver, "!include common_solver.i", content)

    # Update generate_output to include stress components
    old_elas = (
        "generate_output = 'vonmises_stress strain_xx strain_yy "
        "strain_zz strain_xy strain_yz strain_xz'"
    )
    new_elas = (
        "# generate_output = 'vonmises_stress strain_xx strain_yy "
        "strain_zz strain_xy strain_yz strain_xz'\n"
        "        generate_output = 'vonmises_stress strain_xx strain_yy "
        "strain_zz strain_xy strain_yz strain_xz stress_xx stress_yy "
        "stress_zz stress_xy stress_yz stress_xz'"
    )
    content = content.replace(old_elas, new_elas)

    old_plas = (
        "generate_output = 'vonmises_stress strain_xx strain_yy "
        "strain_zz strain_xy strain_yz strain_xz plastic_strain_xx "
        "plastic_strain_yy plastic_strain_zz plastic_strain_xy "
        "plastic_strain_yz plastic_strain_xz'"
    )
    new_plas = (
        "# generate_output = 'vonmises_stress strain_xx strain_yy "
        "strain_zz strain_xy strain_yz strain_xz plastic_strain_xx "
        "plastic_strain_yy plastic_strain_zz plastic_strain_xy "
        "plastic_strain_yz plastic_strain_xz'\n"
        "        generate_output = 'vonmises_stress strain_xx strain_yy "
        "strain_zz strain_xy strain_yz strain_xz plastic_strain_xx "
        "plastic_strain_yy plastic_strain_zz plastic_strain_xy "
        "plastic_strain_yz plastic_strain_xz stress_xx stress_yy "
        "stress_zz stress_xy stress_yz stress_xz'"
    )
    content = content.replace(old_plas, new_plas)

    # Replace outputs block with include
    pattern_outputs = r"\[Outputs\][\s\S]*?\[\]"
    content = re.sub(
        pattern_outputs, "!include common_outputs.i", content
    )

    # Replace BCs block with updated lateral-expansion version
    is_plastic = "plas" in name
    if is_plastic:
        bc_replacement = (
            "[BCs]\n"
            "    [bottom_x]\n"
            "        type = ADDirichletBC\n"
            "        variable = disp_x\n"
            "        boundary = 'bc-bot-point-back bc-bot-point-front'\n"
            "        value = 0.0\n"
            "    []\n"
            "    [bottom_y]\n"
            "        type = ADDirichletBC\n"
            "        variable = disp_y\n"
            "        boundary = 'bc-bot'\n"
            "        value = 0.0\n"
            "    []\n"
            "    [bottom_z]\n"
            "        type = ADDirichletBC\n"
            "        variable = disp_z\n"
            "        boundary = 'bc-bot-point-back'\n"
            "        value = 0.0\n"
            "    []\n\n"
            "    [top_y]\n"
            "        type = ADFunctionDirichletBC\n"
            "        variable = disp_y\n"
            "        boundary = 'bc-top'\n"
            "        function = '${topDispRate}*t'\n"
            "    []\n"
            "[]"
        )
    else:
        bc_replacement = (
            "[BCs]\n"
            "    [bottom_x]\n"
            "        type = DirichletBC\n"
            "        variable = disp_x\n"
            "        boundary = 'bc-bot-point-back bc-bot-point-front'\n"
            "        value = 0.0\n"
            "    []\n"
            "    [bottom_y]\n"
            "        type = DirichletBC\n"
            "        variable = disp_y\n"
            "        boundary = 'bc-bot'\n"
            "        value = 0.0\n"
            "    []\n"
            "    [bottom_z]\n"
            "        type = DirichletBC\n"
            "        variable = disp_z\n"
            "        boundary = 'bc-bot-point-back'\n"
            "        value = 0.0\n"
            "    []\n\n"
            "    [top_y]\n"
            "        type = FunctionDirichletBC\n"
            "        variable = disp_y\n"
            "        boundary = 'bc-top'\n"
            "        function = '${topDispRate}*t'\n"
            "    []\n"
            "[]"
        )

    pattern_bcs = r"\[BCs\][\s\S]*?\n\[\]"
    content = re.sub(pattern_bcs, bc_replacement, content)

    file_path.write_text(content)
    print(f"Refactored: {file_path.name}")


def convert_file_to_2d(file_path: Path) -> None:
    content = file_path.read_text()

    # Replace 3D point-based BCs with 2D boundary name
    content = content.replace(
        "boundary = 'bc-bot-point-back bc-bot-point-front'",
        "boundary = 'bc-bot-mid'",
    )

    # 1. Replace displacements in GlobalParams
    content = content.replace(
        "displacements = 'disp_x disp_y disp_z'",
        "displacements = 'disp_x disp_y'\n"
        "    out_of_plane_strain = scalar_strain_zz",
    )

    # 2. Replace mesh file names
    content = content.replace(
        "mesh3d_holeplate.msh", "mesh2d_holeplate.msh"
    )
    content = content.replace(
        "mesh3d_notchplate.msh", "mesh2d_notchplate.msh"
    )

    # 3. Add planar formulation and clean generate_output
    content = content.replace(
        "strain = SMALL",
        "strain = SMALL\n"
        "        planar_formulation = WEAK_PLANE_STRESS",
    )
    content = content.replace(
        "strain = FINITE",
        "strain = FINITE\n"
        "        planar_formulation = WEAK_PLANE_STRESS",
    )

    # Remove yz and xz outputs
    content = content.replace(" strain_yz strain_xz", "")
    content = content.replace(
        " plastic_strain_yz plastic_strain_xz", ""
    )
    content = content.replace(" stress_yz stress_xz", "")

    # 4. Add Variables block for scalar_strain_zz
    variables_block = (
        "[Variables]\n"
        "    [scalar_strain_zz]\n"
        "    []\n"
        "[]\n\n"
    )
    content = variables_block + content

    # 5. Remove bottom_z and top_z from BCs
    content = re.sub(r"\s*\[bottom_z\][\s\S]*?\[\]", "", content)
    content = re.sub(r"\s*\[top_z\][\s\S]*?\[\]", "", content)

    # 7. Update simName in Outputs
    content = content.replace("hole3d_", "hole2d_")
    content = content.replace("notch3d_", "notch2d_")

    # Determine 2D filename
    new_name = file_path.name.replace("3d", "2d")
    new_path = file_path.parent / new_name
    new_path.write_text(content)
    print(f"Generated 2D: {new_path.name}")


def main() -> None:
    data_dir = Path(__file__).resolve().parent
    # Find and refactor all 3D files, then convert them to 2D
    for file_path in sorted(data_dir.glob("*3d*.i")):
        refactor_file(file_path)
        convert_file_to_2d(file_path)


if __name__ == "__main__":
    main()
