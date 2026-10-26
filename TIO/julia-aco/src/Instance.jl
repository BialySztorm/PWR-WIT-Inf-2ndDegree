module InstanceMod

using JSON3

export Instance, load_instance, included_cells, start_xy, start_height, height_at, cell_count

struct Instance
    name::String
    cell_size_m::Float64
    width::Int
    height::Int
    terrain::Vector{Float64}
    excluded_cells::Vector{Tuple{Int,Int}}
    agl_target_m::Float64
    drone_max_rel_takeoff_m::Float64
    speed_mps::Float64
    usable_flight_s::Float64
    start_x::Int
    start_y::Int
end

function load_instance(path::AbstractString)
    j = JSON3.read(read(path, String))
    raw_excluded = get(j, :excluded_cells, [])
    excluded = raw_excluded === nothing ? Tuple{Int,Int}[] : [(Int(c[1]), Int(c[2])) for c in raw_excluded]
    cand = j.takeoff.candidates[1]
    Instance(
        String(j.name),
        Float64(j.grid.cell_size_m),
        Int(j.grid.width),
        Int(j.grid.height),
        Float64.(collect(j.terrain)),
        excluded,
        Float64(j.flight.agl_target_m),
        Float64(j.flight.drone_max_rel_takeoff_m),
        Float64(j.flight.speed_mps),
        Float64(j.battery.usable_flight_s),
        Int(cand.x),
        Int(cand.y),
    )
end

cell_count(inst::Instance) = inst.width * inst.height

@inline idx(inst::Instance, x::Int, y::Int) = y * inst.width + x + 1

@inline height_at(inst::Instance, x::Int, y::Int) = inst.terrain[idx(inst, x, y)]

function included_cells(inst::Instance)
    excl = Set(inst.excluded_cells)
    cells = Tuple{Int,Int}[]
    for y in 0:inst.height-1, x in 0:inst.width-1
        if (x, y) ∉ excl
            push!(cells, (x, y))
        end
    end
    cells
end

start_xy(inst::Instance) = (inst.start_x * inst.cell_size_m, inst.start_y * inst.cell_size_m)
start_height(inst::Instance) = height_at(inst, inst.start_x, inst.start_y)

end # module
