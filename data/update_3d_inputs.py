from pathlib import Path


def update_file(file_path: Path) -> None:
    content = file_path.read_text()

    # Update variables
    content = content.replace("endTime = 24", "endTime = 32")
    content = content.replace("maxDisp = 0.02e-3", "maxDisp = 0.2e-3")
    content = content.replace("maxDisp = 0.05e-3", "maxDisp = 0.5e-3")

    # Update outputs (elastic)
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

    # Update outputs (plastic)
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

    file_path.write_text(content)
    print(f"Updated 3D: {file_path.name}")


def main() -> None:
    data_dir = Path(__file__).resolve().parent
    for file_path in sorted(data_dir.glob("*3d*.i")):
        update_file(file_path)


if __name__ == "__main__":
    main()
