module DecoderMod

using ..InstanceMod: Instance, start_xy, start_height, height_at

export CostBreakdown, decode_order

const W_TURN = 2.0
const W_CLIMB = 3.0
const W_SWAP = 1.0
const W_VIOL = 50.0

struct CostBreakdown
    flight_time_s::Float64
    turn_penalty::Float64
    climb_cost::Float64
    battery_swaps::Int
    swap_before_step::Vector{Int}
    violations::Float64
    total::Float64
    feasible::Bool
end

"""
    decode_order(order, inst)

Mirrors go-ga/internal/ga/decoder.go and rust-ga/src/decoder.rs: splits the
visiting order into battery-limited flights from/to the fixed base and sums
up flight time, turn penalty, climb cost, battery swaps and height-limit
violations into a single mission cost.
"""
function decode_order(order::Vector{Tuple{Int,Int}}, inst::Instance)
    start_x, start_y = start_xy(inst)
    start_h = start_height(inst)

    flight_time_s = 0.0
    turn_penalty = 0.0
    climb_cost = 0.0
    battery_swaps = 0
    swap_before_step = Int[]
    violations = 0.0

    cur_x, cur_y, cur_h = start_x, start_y, start_h
    have_prev_heading = false
    prev_hx, prev_hy = 0.0, 0.0
    flight_elapsed = 0.0
    speed = inst.speed_mps

    segment_cost = function (x1, y1, h1, x2, y2, h2, have_prev_h, phx, phy)
        dx, dy = x2 - x1, y2 - y1
        dist = hypot(dx, dy)
        t = dist / speed
        hx, hy = dist > 1e-9 ? (dx / dist, dy / dist) : (phx, phy)
        turn = 0.0
        if have_prev_h && dist > 1e-9
            cosA = clamp(phx * hx + phy * hy, -1.0, 1.0)
            turn = acos(cosA)
        end
        climb = max(0.0, h2 - h1)
        (t, turn, climb, hx, hy)
    end

    return_time_from = (x, y) -> hypot(start_x - x, start_y - y) / speed

    for (i, (cx, cy)) in enumerate(order)
        x = cx * inst.cell_size_m
        y = cy * inst.cell_size_m
        h = height_at(inst, cx, cy)

        t, turn, climb, hx, hy = segment_cost(cur_x, cur_y, cur_h, x, y, h, have_prev_heading, prev_hx, prev_hy)
        needed_if_stop_here = flight_elapsed + t + W_TURN * turn + W_CLIMB * climb + return_time_from(x, y)

        if needed_if_stop_here > inst.usable_flight_s && flight_elapsed > 0.0
            flight_time_s += return_time_from(cur_x, cur_y)
            battery_swaps += 1
            push!(swap_before_step, i - 1)
            cur_x, cur_y, cur_h = start_x, start_y, start_h
            flight_elapsed = 0.0
            t, turn, climb, hx, hy = segment_cost(cur_x, cur_y, cur_h, x, y, h, false, 0.0, 0.0)
        end

        rel_height = (h + inst.agl_target_m) - start_h
        if rel_height > inst.drone_max_rel_takeoff_m
            violations += rel_height - inst.drone_max_rel_takeoff_m
        end

        seg_time = t + W_TURN * turn + W_CLIMB * climb
        flight_time_s += t
        turn_penalty += turn
        climb_cost += climb
        flight_elapsed += seg_time

        cur_x, cur_y, cur_h = x, y, h
        prev_hx, prev_hy, have_prev_heading = hx, hy, true
    end
    flight_time_s += return_time_from(cur_x, cur_y)

    total = flight_time_s + W_TURN * turn_penalty + W_CLIMB * climb_cost +
            W_SWAP * battery_swaps + W_VIOL * violations
    CostBreakdown(flight_time_s, turn_penalty, climb_cost, battery_swaps, swap_before_step, violations, total, violations == 0.0)
end

end # module
