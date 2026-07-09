from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
import pyvista as pv
import pyvale.sensorsim as sens
import pyvale.mooseherder as mh


def interp_sim_to_grid(interp_grid: np.ndarray, # shape=(3,Nx,Ny,Nz)
                       sim_data: mh.SimData,
                       comp_keys: tuple[str,...],
                       spatial_dims: sens.EDim = sens.EDim.THREED,
                       ) -> np.ndarray:

    # interp_grid shape is (3, Nx, Ny, Nz) -> spatial_shape is (Nx, Ny, Nz)
    spatial_grid_shape = interp_grid.shape[1:]

    # Reshape to (N_total_points, 3)
    interp_points = interp_grid.reshape(3, -1).T

    pyvista_interp = sens.simdata_to_pyvista_interp(sim_data,
                                                    comp_keys,
                                                    spatial_dims)
    pv_points = pv.PolyData(interp_points)
    sample_data = pv_points.sample(pyvista_interp)

    invalid = ~sample_data["vtkValidPointMask"].astype(bool)

    n_comps = len(comp_keys)
    (n_sensors,n_time_steps) = np.array(sample_data[comp_keys[0]]).shape
    sample_at_sim_time = np.empty((n_sensors,n_comps,n_time_steps))

    for ii,cc in enumerate(comp_keys):
        data_mat = np.array(sample_data[cc])
        data_mat[invalid,:] = np.nan
        sample_at_sim_time[:,ii,:] = data_mat

    # Target: (Nx, Ny, Nz, n_comps, n_time_steps)
    final_shape = spatial_grid_shape + (n_comps, n_time_steps)
    grid_data = sample_at_sim_time.reshape(final_shape)

    return grid_data


def inner_vec_by_step(lower: float, upper: float, step: float) -> np.ndarray:
    start = lower + step/2
    stop = upper - step/2
    num_pts = int(round((stop - start) / step)) + 1
    return np.linspace(start, stop, num_pts)


def inner_vec_by_divs(lower: float, upper: float, divs: int) -> np.ndarray:
    step = (upper - lower) / divs
    start = lower + (step / 2)
    stop = upper - (step / 2)
    return np.linspace(start, stop, divs)


def main() -> None:
    #----------------------------------------------------------------------
    # Loading in the exodus simulation output
    exodus_name = "notch3d_elas_het_24f.e"
    # notch3d_elas_24f.e
    # notch3d_elas_het_24f.e
    # notch3d_plas_24f.e
    # notch3d_plas_het_24f.e
    # OR plate3d_elas_24f.e etc

    script_path = Path(__file__).resolve().parent
    print(f"{script_path=}")

    output_path = script_path.parent / 'data'
    print(f"{output_path=}")

    output_exodus = output_path / exodus_name
    exodus_reader = mh.ExodusLoader(output_exodus)

    print("\nReading exodus file with ExodusReader:")
    print(f"{output_exodus=}\n")

    sim_data = exodus_reader.load_all_sim_data()

    # Prints out the fields of our dataclass so we can see what we have.
    print("SimData from 'load_all':")
    sens.simtools.print_sim_data(sim_data)

    sens.simtools.print_dimensions(sim_data)

    #----------------------------------------------------------------------
    # Example for how to interpolate the simulation data.

    # Create the meshgrid in (Nx, Ny, Nz) order
    grid_pts = 101
    plate_height = 35.0
    plate_width = 25.0
    plate_thick = 1.0

    x_vec = inner_vec_by_divs(plate_width/2,-plate_width/2,grid_pts)
    y_vec = (inner_vec_by_divs(plate_width/2,-plate_width/2,grid_pts)
             + plate_height/2)
    z_vec = np.full((1,),0.0,dtype=np.float64)

    print("\nGrid Vectors:")
    print(f"{x_vec.shape=}")
    print(f"{y_vec.shape=}")
    print(f"{z_vec.shape=}")

    (x_grid, y_grid, z_grid) = np.meshgrid(x_vec, y_vec, z_vec, indexing='ij')
        # Stack them along a new first axis to create the (3, Nx, Ny, Nz) array
    interp_grid = np.stack([x_grid, y_grid, z_grid], axis=0)
    print("interp_grid.shape=(3,Nx,Ny,Nz)")
    print(f"{interp_grid.shape=}")


    interp_fields = interp_sim_to_grid(interp_grid,
                                       sim_data,
                                       ("strain_xx","strain_yy","strain_xy"))

    print()
    print("Interpolated Sim Fields:")
    print("interp_fields.shape=(Nx,Ny,Nz,field_comp,time_steps)")
    print("    where, field_comp 0 is strain_xx etc")
    print(f"{interp_fields.shape=}")
    print()

    # Extract 2D slices for strain components at final time step
    # Gives the 2D slice in normal image Y,X format
    slice_xx = interp_fields[:, :, 0, 0, -1].T
    slice_yy = interp_fields[:, :, 0, 1, -1].T
    slice_xy = interp_fields[:, :, 0, 2, -1].T

    # Coordinates for the slices
    x_slice = x_grid[:, :, 0].T
    y_slice = y_grid[:, :, 0].T

    print("Load Cell Data:")
    load_cell = sim_data.glob_vars["react_y_top"]
    print(f"{load_cell.shape=}")
    print(f"{np.max(load_cell)=:.3f} Newtons")
    print()

    #---------------------------------------------------------------------------
    # Plot the fields on a grid
    fig, axes = plt.subplots(1, 3, figsize=(18, 5), sharey=True)

    components = [
        ("Strain XX", slice_xx),
        ("Strain YY", slice_yy),
        ("Strain XY", slice_xy),
    ]

    for idx, (name, data) in enumerate(components):
        ax = axes[idx]
        mesh = ax.pcolormesh(
            x_slice,
            y_slice,
            data,
            shading="nearest",
            cmap="viridis",
        )
        fig.colorbar(mesh, ax=ax, label=name)
        ax.set_xlabel("X (mm)")
        if idx == 0:
            ax.set_ylabel("Y (mm)")
        ax.set_title(f"{name} Slice at Final Time Step")

    plt.tight_layout()

    # Save the plot
    images_dir = script_path.parent / "images"
    images_dir.mkdir(exist_ok=True)
    plot_file = images_dir / "strain_components_heatmap.png"
    plt.savefig(plot_file, dpi=300, bbox_inches="tight")
    print(f"Saved plot to {plot_file}")


if __name__ == "__main__":
    main()
