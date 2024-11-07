# Simulate.jl
module Simulate

export simulate, get_actions

using Base.Threads

const FEE = 0.005

mutable struct Node
    value::Float64
    usd::Float64
    btc::Float64
    parent::Union{Node,Nothing}
    action::Symbol  # :buy_hold or :sell_usd
    prev_action::Symbol  # Previous action in the branch
end

@inline function buyNode(_usd::Float64, _btc::Float64, open::Float64, close::Float64, fee::Float64, prev_action::Symbol)
    if _usd > 0
        btc = (_usd * (1 - fee)) / open
        return Node(btc * max(open, close), 0.0, btc, nothing, :buy_hold, prev_action)
    end
    return Node(_btc * max(open, close), 0.0, _btc, nothing, :buy_hold, prev_action)
end

@inline function sellNode(_usd::Float64, _btc::Float64, open::Float64, fee::Float64, prev_action::Symbol)
    if _btc > 0
        usd = _btc * open * (1 - fee)
        return Node(usd, usd, 0.0, nothing, :sell_usd, prev_action)
    end
    return Node(_usd, _usd, 0.0, nothing, :sell_usd, prev_action)
end

@inline function should_continue_branch(current_action::Symbol, prev_action::Symbol, prev_prev_action::Symbol)
    return !(
        (current_action == :buy_hold && prev_action == :sell_usd && prev_prev_action == :buy_hold) ||
        (current_action == :sell_usd && prev_action == :buy_hold && prev_prev_action == :sell_usd)
    )
end

Base.@propagate_inbounds function simulate(
    matrix::Matrix{Float64},
    current_price_index::Int,
    init_value::Float64,
    period::Int,
    start_with_usd::Bool,
    root_prev_action::Symbol = :none
)
    head = if start_with_usd
        Node(init_value, init_value, 0.0, nothing, :sell_usd, root_prev_action)
    else
        open = matrix[current_price_index, 1]
        Node(init_value, 0.0, init_value / open, nothing, :buy_hold, root_prev_action)
    end

    total_nodes = 2^(period + 1) - 1
    nodes = Vector{Node}(undef, total_nodes)
    leaf_nodes = Vector{Node}(undef, 2^period)
    nodes[1] = head
    node_idx = 2
    idxs = 1:1
    k, lck = 1, SpinLock()

    @inbounds for i in 1:period
        @threads for j in idxs
            cur = nodes[j]
            @fastmath begin
                # BUY_HOLD NODE
                if (cur.value - init_value) / init_value > -(FEE * 5)
                    if should_continue_branch(:buy_hold, cur.action, cur.prev_action)
                        buy_node = buyNode(cur.usd, cur.btc, matrix[current_price_index+i, 1], matrix[current_price_index+i, 2], FEE, cur.action)
                        buy_node.parent = cur
                        lock(lck)
                        nodes[node_idx] = buy_node
                        node_idx += 1
                        unlock(lck)
                        if i == period
                            lock(lck)
                            leaf_nodes[k] = buy_node
                            k += 1
                            unlock(lck)
                        end
                    end

                    # SELL_USD NODE
                    if should_continue_branch(:sell_usd, cur.action, cur.prev_action)
                        sell_node = sellNode(cur.usd, cur.btc, matrix[current_price_index+i, 1], FEE, cur.action)
                        sell_node.parent = cur
                        lock(lck)
                        nodes[node_idx] = sell_node
                        node_idx += 1
                        unlock(lck)
                        if i == period
                            lock(lck)
                            leaf_nodes[k] = sell_node
                            k += 1
                            unlock(lck)
                        end
                    end
                end
            end
        end
        idxs = (idxs[end]+1):node_idx-1
    end
    return leaf_nodes[argmax(map(n -> n.value, leaf_nodes[1:k-1]))]
end

function get_actions(node::Node)
    cur = node
    actions = []
    while cur.parent != nothing
        action = cur.action == :buy_hold ? 1 : 2
        push!(actions, action)
        cur = cur.parent
    end
    return reverse(actions)
end

end # module


#=using CSV, DataFrames, Dates
df = CSV.read("Data/1DAY.csv", DataFrame)
matrix = Matrix(df[:, [:open, :close]])
node = simulate(matrix, 30, 1000.0, 31, true, :sell_usd)
actions = get_actions(node)
println(reverse(actions))=#
