import re
from pathlib import Path


def refactor_file(file_path: Path) -> None:
    content = file_path.read_text()

    # 1. Replace variables block
    name = file_path.name
    if "elas_het" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_het_geometry.i\n"
            "PRatio = 0.3      # -\n"
            "EModInf = 200e9         # Pa, modulus \n"
            "far from the bump\n"
            "PeakEMod = 240e9        # Pa, modulus \n"
            "at the bump centre\n"
            "#** MOOSEHERDER VARIABLES - END"
        )
    elif "plas_het" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_het_geometry.i\n"
            "EMod = 200e9       # Pa\n"
            "PRatio = 0.3       # -\n"
            "HardMod = 1000e6   # Pa\n"
            "YieldInf = 200e6         # Pa, yield \n"
            "stress far from the bump\n"
            "PeakYield = 240e6        # Pa, yield \n"
            "stress at the bump centre\n"
            "#** MOOSEHERDER VARIABLES - END"
        )
    elif "elas" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_elas_props.i\n"
            "#** MOOSEHERDER VARIABLES - END"
        )
    elif "plas" in name:
        var_replacement = (
            "#_* MOOSEHERDER VARIABLES - START\n"
            "!include common_load_time.i\n"
            "!include common_plas_props.i\n"
            "#** MOOSEHERDER VARIABLES - END"
        )

    # Locate and replace variables block
    pattern_var = (
        r"#_\* MOOSEHERDER VARIABLES - START[\s\S]*?"
        r"#\*\* MOOSEHERDER VARIABLES - END"
    )
    content = re.sub(pattern_var, var_replacement, content)

    # 2. Replace solver blocks with include
    pattern_solver = (
        r"\[Preconditioning\][\s\S]*?\[Executioner\]"
        r"[\s\S]*?\[Predictor\][\s\S]*?\[\]\s*\[\]"
    )
    content = re.sub(pattern_solver, "!include common_solver.i", content)

    file_path.write_text(content)
    print(f"Refactored: {file_path.name}")


def main() -> None:
    data_dir = Path(__file__).resolve().parent
    for file_path in sorted(data_dir.glob("*3d*.i")):
        refactor_file(file_path)


if __name__ == "__main__":
    main()
