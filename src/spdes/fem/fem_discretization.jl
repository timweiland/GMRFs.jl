using Ferrite
import Ferrite: ndofs

export FEMDiscretization, ndim, evaluation_matrix, node_selection_matrix

"""
    FEMDiscretization(grid, interpolation, quadrature_rule)

A struct that contains all the information needed to discretize
a (S)PDE using the Finite Element Method.
"""
struct FEMDiscretization{
    D,
    S,
    G<:Grid{D},
    I<:Interpolation{S},
    Q<:QuadratureRule{S},
    GI<:Interpolation{S},
    H<:DofHandler{D,G},
    CH<:Union{ConstraintHandler{H},Nothing},
}
    grid::G
    interpolation::I
    quadrature_rule::Q
    geom_interpolation::GI
    dof_handler::H
    constraint_handler::CH

    function FEMDiscretization(
        grid::G,
        interpolation::I,
        quadrature_rule::Q,
        fields = ((:u, nothing),),
        boundary_conditions = (),
    ) where {D,S,G<:Grid{D},I<:Interpolation{S},Q<:QuadratureRule{S}}
        default_geom_interpolation = interpolation
        dh = DofHandler(grid)
        for (field, geom_interpolation) in fields
            if geom_interpolation === nothing
                geom_interpolation = default_geom_interpolation
            end
            add!(dh, field, geom_interpolation)
        end
        close!(dh)

        ch = ConstraintHandler(dh)
        if length(boundary_conditions) > 0
            for bc in boundary_conditions
                add!(ch, bc)
            end
        end
        close!(ch)
        new{D,S,G,I,Q,I,DofHandler{D,G},typeof(ch)}(
            grid,
            interpolation,
            quadrature_rule,
            default_geom_interpolation,
            dh,
            ch,
        )
    end

    function FEMDiscretization(
        grid::G,
        interpolation::I,
        quadrature_rule::Q,
        geom_interpolation::GI,
    ) where {D,S,G<:Grid{D},I<:Interpolation{S},Q<:QuadratureRule{S},GI<:Interpolation{S}}
        dh = DofHandler(grid)
        add!(dh, :u, geom_interpolation)
        close!(dh)
        new{D,S,G,I,Q,GI,DofHandler{D,G},Nothing}(
            grid,
            interpolation,
            quadrature_rule,
            geom_interpolation,
            dh,
            nothing,
        )
    end
end

"""
    ndim(f::FEMDiscretization)

Return the dimension of space in which the discretization is defined.
Typically ndim(f) == 1, 2, or 3.
"""
ndim(::FEMDiscretization{D}) where {D} = D

"""
    ndofs(f::FEMDiscretization)

Return the number of degrees of freedom in the discretization.
"""
ndofs(f::FEMDiscretization) = f.dof_handler.ndofs

"""
    evaluation_matrix(f::FEMDiscretization, X)

Return the matrix A such that A[i, j] is the value of the j-th basis function
at the i-th point in X.
"""
function evaluation_matrix(f::FEMDiscretization, X; field = :default)
    if field == :default
        field = first(f.dof_handler.field_names)
    end
    dof_idcs = dof_range(f.dof_handler, field)
    peh = PointEvalHandler(f.grid, X)
    cc = CellCache(f.dof_handler)
    Is = Int64[]
    Js = Int64[]
    Vs = Float64[]
    for i in eachindex(peh.cells)
        reinit!(cc, peh.cells[i])
        dofs = celldofs(cc)[dof_idcs]
        append!(Is, repeat([i], length(dofs)))
        append!(Js, dofs)
        vals = [
            Ferrite.reference_shape_value(f.interpolation, peh.local_coords[i], j) for
            j = 1:getnbasefunctions(f.interpolation)
        ]
        append!(Vs, vals)
    end
    return sparse(Is, Js, Vs, length(X), ndofs(f))
end

"""
    node_selection_matrix(f::FEMDiscretization, node_ids)

Return the matrix A such that A[i, j] = 1 if the j-th basis function
is associated with the i-th node in node_ids.
"""
function node_selection_matrix(f::FEMDiscretization, node_ids; field = :default)
    if field == :default
        field = first(f.dof_handler.field_names)
    end
    dof_idcs = dof_range(f.dof_handler, field)
    node_coords = map(n -> f.grid.nodes[n].x, node_ids)
    peh = PointEvalHandler(f.grid, node_coords)
    cc = CellCache(f.dof_handler)
    Is = Int64[]
    Js = Int64[]
    Vs = Float64[]
    for i in eachindex(peh.cells)
        reinit!(cc, peh.cells[i])
        dofs = celldofs(cc)[dof_idcs]
        coords = getcoordinates(cc)
        for j = 1:length(dofs)
            if coords[j] ≈ node_coords[i]
                push!(Is, i)
                push!(Js, dofs[j])
                push!(Vs, 1)
            end
        end
    end
    return sparse(Is, Js, Vs, length(node_ids), ndofs(f))
end


function Base.show(io::IO, discretization::FEMDiscretization)
    println(io, "FEMDiscretization")
    println(io, "  grid: ", repr(MIME("text/plain"), discretization.grid))
    println(io, "  interpolation: ", discretization.interpolation)
    println(io, "  quadrature_rule: ", discretization.quadrature_rule)
end
