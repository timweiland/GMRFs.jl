module GMRFs

include("typedefs.jl")
include("utils/to_matrix.jl")
include("linear_maps/ad_jacobian.jl")
include("linear_maps/sparse_ad_jacobian.jl")
include("linear_maps/symmetric_block_tridiagonal.jl")
include("linear_maps/outer_product.jl")
include("preconditioners/preconditioner.jl")
include("preconditioners/full_cholesky.jl")
include("preconditioners/block_jacobi.jl")
include("preconditioners/tridiag_block_gauss_seidel.jl")
include("gmrf.jl")
include("linear_conditional_gmrf.jl")
include("spdes/fem/fem_discretization.jl")
include("spdes/fem/fem_derivatives.jl")
include("spdes/fem/utils.jl")
include("linear_ssm.jl")
include("implicit_euler_ssm.jl")
include("spatiotemporal_gmrf.jl")
include("solvers/solver.jl")
include("solvers/cholesky_solver.jl")
include("solvers/cg_solver.jl")
include("solvers/default_solver.jl")
include("solvers/variance/variance_strategy.jl")
include("solvers/variance/rbmc.jl")
include("solvers/variance/takahashi.jl")
include("spdes/spde.jl")
include("spdes/matern.jl")
include("spdes/advection_diffusion.jl")
include("gmrf_arithmetic.jl")
include("plot_utils.jl")
include("mesh_utils.jl")

end
