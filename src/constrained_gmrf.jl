using Random, LinearMaps, Ferrite
import Random: rand!

export ConstrainedGMRF,
    full_mean,
    full_var,
    full_std,
    full_rand,
    transform_free_to_full,
    constrainify_linear_system

#####################
#
#    ConstrainedGMRF
#
#####################
"""
    ConstrainedGMRF{G, T}(inner_gmrf, prescribed_dofs, free_dofs, free_to_prescribed_map)

A GMRF with hard affine constraints with mean `mean` and
precision matrix `precision`.

"""
struct ConstrainedGMRF{G<:AbstractGMRF,T} <: AbstractGMRF
    inner_gmrf::G
    prescribed_dofs::AbstractVector{Int64}
    free_dofs::AbstractVector{Int64}
    free_to_prescribed_map::LinearMap{T}
    free_to_prescribed_offset::AbstractVector{T}

    function ConstrainedGMRF(
        inner_gmrf::G,
        prescribed_dofs::AbstractVector{Int64},
        free_dofs::AbstractVector{Int64},
        free_to_prescribed_map::LinearMap{T},
        free_to_prescribed_offset::AbstractVector{T},
    ) where {G<:AbstractGMRF,T}
        n = length(mean(inner_gmrf))
        # (length(prescribed_dofs) + length(free_dofs)) == n ||
        #     throw(ArgumentError("size mismatch"))
        # size(free_to_prescribed_map, 1) == length(prescribed_dofs) ||
        #     throw(ArgumentError("size mismatch"))
        # size(free_to_prescribed_map, 2) == length(prescribed_dofs) ||
        #     throw(ArgumentError("size mismatch"))
        new{G,T}(
            inner_gmrf,
            prescribed_dofs,
            free_dofs,
            free_to_prescribed_map,
            free_to_prescribed_offset,
        )
    end

    function ConstrainedGMRF(
        inner_gmrf::AbstractGMRF,
        constraint_handler::Ferrite.ConstraintHandler,
    )
        prescribed_dofs = constraint_handler.prescribed_dofs
        free_dofs = constraint_handler.free_dofs
        free_to_prescribed_mat = spzeros(length(prescribed_dofs), length(inner_gmrf))
        free_to_prescribed_offset = zeros(length(prescribed_dofs))
        for (i, p_dof) in enumerate(prescribed_dofs)
            constraint_idx = constraint_handler.dofmapping[p_dof]
            dofcoefficients = constraint_handler.dofcoefficients[constraint_idx]
            if dofcoefficients !== nothing
                for (f_dof, val) in constraint_handler.dofcoefficients[constraint_idx]
                    free_to_prescribed_mat[i, f_dof] = val
                end
            end
            affine_inhomogeneity = constraint_handler.affine_inhomogeneities[constraint_idx]
            if affine_inhomogeneity !== nothing
                free_to_prescribed_offset[i] = affine_inhomogeneity
            end
        end
        free_to_prescribed_map = LinearMap(free_to_prescribed_mat)
        ConstrainedGMRF(
            inner_gmrf,
            prescribed_dofs,
            free_dofs,
            free_to_prescribed_map,
            free_to_prescribed_offset,
        )
    end
end

length(d::ConstrainedGMRF) = length(d.inner_gmrf)
mean(d::ConstrainedGMRF) = mean(d.inner_gmrf)
precision_map(d::ConstrainedGMRF) = precision_map(d.inner_gmrf)
var(d::ConstrainedGMRF) = var(d.inner_gmrf)
rand!(rng::AbstractRNG, d::ConstrainedGMRF, x::AbstractVector) = rand!(rng, d.inner_gmrf, x)

function transform_free_to_full(d::ConstrainedGMRF, x::AbstractVector)
    res = copy(x)
    res[d.prescribed_dofs] +=
        d.free_to_prescribed_map * Array(x) + d.free_to_prescribed_offset
    return res
end

@memoize full_mean(d::ConstrainedGMRF) = transform_free_to_full(d, mean(d))
full_rand(rng::AbstractRNG, d::ConstrainedGMRF) =
    transform_free_to_full(d, rand(rng, d.inner_gmrf))

@memoize full_var(d::ConstrainedGMRF) = transform_free_to_full(d, var(d))

full_mean(d::AbstractGMRF) = mean(d)
full_rand(rng::AbstractRNG, d::AbstractGMRF) = rand(rng, d)
full_var(d::AbstractGMRF) = var(d)
full_std(d::AbstractGMRF) = sqrt.(full_var(d))

function constrainify_linear_system(A::AbstractArray, y::AbstractVector, x::ConstrainedGMRF)
    free_to_prescribed_mat = to_matrix(x.free_to_prescribed_map)
    for (i, p_dof) in enumerate(x.prescribed_dofs)
        col_i = A[:, p_dof]
        f_dofs, coeffs = findnz(free_to_prescribed_mat[i, :])
        rhs = x.free_to_prescribed_offset[i]
        y -= rhs * col_i
        for (f_dof, coeff) in zip(f_dofs, coeffs)
            A[:, f_dof] += coeff * col_i
        end
        A[:, p_dof] .= 0
    end
    return A, y
end
