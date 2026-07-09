import re
from pathlib import Path

def convert_file(file_path: Path) -> None:
    content = file_path.read_text()

    # 1. Replace displacements in GlobalParams
    content = content.replace(
        "displacements = 'disp_x disp_y disp_z'",
        "displacements = 'disp_x disp_y'\n"
        "    out_of_plane_strain = scalar_strain_zz"
    )

    # 2. Replace mesh file names
    content = content.replace(
        "mesh3d_holeplate.msh",
        "mesh2d_holeplate.msh"
    )
    content = content.replace(
        "mesh3d_notchplate.msh",
        "mesh2d_notchplate.msh"
    )

    # 3. Add planar formulation and clean generate_output
    content = content.replace(
        "strain = SMALL",
        "strain = SMALL\n"
        "        planar_formulation = WEAK_PLANE_STRESS"
    )
    content = content.replace(
        "strain = FINITE",
        "strain = FINITE\n"
        "        planar_formulation = WEAK_PLANE_STRESS"
    )

    # Remove yz and xz outputs
    content = content.replace(" strain_yz strain_xz", "")
    content = content.replace(" plastic_strain_yz plastic_strain_xz", "")
    content = content.replace(" stress_yz stress_xz", "")

    # 4. Add Variables block for scalar_strain_zz
    variables_block = (
        "[Variables]\n"
        "    [scalar_strain_zz]\n"
        "    []\n"
        "[]"
    )
    end_marker = (
        "#** MOOSEHERDER VARIABLES - END\n"
        "#-------------------------------------------------------"
        "------------------"
    )
    if end_marker in content:
        content = content.replace(
            end_marker,
            f"{end_marker}\n\n{variables_block}"
        )
    else:
        end_marker_simple = "#** MOOSEHERDER VARIABLES - END"
        content = content.replace(
            end_marker_simple,
            f"{end_marker_simple}\n\n{variables_block}"
        )

    # 5. Remove bottom_z and top_z from BCs
    content = re.sub(r"\s*\[bottom_z\][\s\S]*?\[\]", "", content)
    content = re.sub(r"\s*\[top_z\][\s\S]*?\[\]", "", content)


    # 7. Update file_base in Outputs
    content = content.replace("hole3d_", "hole2d_")
    content = content.replace("notch3d_", "notch2d_")

    # Determine 2D filename
    new_name = file_path.name.replace("3d", "2d")
    new_path = file_path.parent / new_name
    new_path.write_text(content)
    print(f"Generated: {new_path.name}")

def main() -> None:
    data_dir = Path(__file__).resolve().parent
    for file_path in sorted(data_dir.glob("*3d*.i")):
        convert_file(file_path)

if __name__ == "__main__":
    main()
