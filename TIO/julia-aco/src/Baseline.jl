module BaselineMod

using ..InstanceMod: Instance, included_cells

export boustrophedon

function boustrophedon(inst::Instance)
    cells = included_cells(inst)
    by_column = Dict{Int,Vector{Int}}()
    for (x, y) in cells
        push!(get!(by_column, x, Int[]), y)
    end

    order = Tuple{Int,Int}[]
    forward = true
    for x in 0:inst.width-1
        if haskey(by_column, x)
            ys = by_column[x]
            for y in (forward ? ys : reverse(ys))
                push!(order, (x, y))
            end
            forward = !forward
        end
    end
    order
end

end # module
