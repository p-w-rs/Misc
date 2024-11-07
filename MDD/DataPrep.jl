# DataPrep.jl
module DataPrep

export get_data

using CSV, DataFrames, Dates, StatsBase, OneHotArrays
using ProgressMeter, StatsBase, Random

include("Simulate.jl")
using .Simulate

const FEE = 0.005

function column_zscore(matrix::Matrix)
    mn = mean(matrix, dims=1)
    stddev = std(matrix, dims=1)
    return (matrix .- mn) ./ stddev
end

function get_data(period)
    df = CSV.read("Data/1HRS.csv", DataFrame)
    prices = Matrix(df[:, [:open, :close]])

    nsamples = length(period:size(df, 1)-1)
    features = size(df, 2) - 2
    states = zeros(Float32, features, period, 1, nsamples)
    for (i, j) in enumerate(period:size(df, 1)-1)
        x = Matrix(df[j-period+1:j, 3:end])
        x[:, 1:6] .= column_zscore(x[:, 1:6])
        states[:, :, :, i] .= x'
    end

    actions = zeros(Int, nsamples)
    positions = ones(Int, nsamples) .* 2
    position = 2
    prev_position = 2
    @showprogress for (i, j) in enumerate(period:24:size(df, 1))
        lookn = min(24, size(df, 1)-j)
        lookn == 0 && break
        node = simulate(prices, j, 1000.0, lookn, position == 2, prev_position == 2 ? :sell_usd : :buy_hold)
        actions24 = get_actions(node)
        actions[(i*24)-23:(i*24)-23+lookn-1] .= actions24
        position = actions24[end]
        prev_position = actions24[end-1]
    end
    positions[2:end] .= actions[1:end-1]

    action = 2
    for i in 1:nsamples
        if action == actions[i]
            actions[i] = 3
        else
            action = actions[i]
        end
    end

    xs1, xs2, ys = balance_classes(states, positions, actions)
    return xs1, xs2, ys, states, prices
end

function balance_classes(states, positions, actions)
    class_counts = Dict()
    class_idxs = Dict()
    for i in 1:size(states, 4)
        p = positions[i]
        a = actions[i]
        class_counts[a] = get(class_counts, a, 0) + 1
        push!(get!(class_idxs, a, Int[]), i)
    end
    positions = Float32.(onehotbatch(positions, 1:2))
    actions = Float32.(onehotbatch(actions, 1:3))

    max_count = maximum(values(class_counts))
    for (k, v) in class_counts
        if v < max_count
            idxs = class_idxs[k]
            n = max_count - v
            add_idxs = sample(idxs, n, replace=true)
            class_idxs[k] = vcat(idxs, add_idxs)
        end
    end
    idxs = vcat(values(class_idxs)...)
    deepcopy(states[:, :, :, idxs]), deepcopy(positions[:, idxs]), deepcopy(actions[:, idxs])
end

end # module


#=valleys = zeros(Bool, size(df, 1))
for i in 2:size(df, 1)-1
    valleys[i] = df[i-1, :open] > df[i, :open] < df[i+1, :open]
end
vidxs = findall(valleys)
vidx = 1

peaks = zeros(Bool, size(df, 1))
for i in 2:size(df, 1)-1
    peaks[i] = df[i-1, :open] < df[i, :open] > df[i+1, :open]
end
pidxs = findall(peaks)
pidx = 1

buy_signals = zeros(Bool, size(df, 1))
sell_signals = zeros(Bool, size(df, 1))
while vid <= length(vidxs) && pid <= length(pidxs)
    buy_idx, sell_idx = vidxs[vidx], pidxs[pidx]
    buy_price = df[buy_idx, :open]
    sell_price = df[sell_idx, :open]
    roi = (sell_price - buy_price) / buy_price

    if roi > FEE
        buy_signals[buy_idx] = true
        sell_signals[sell_idx] = true
        vidx, pidx = vidx + 1, pidx + 1
    else
        next_buy = df[vidxs[vidx+1], :open]
        next_sell = df[pidxs[pidx+1], :open]
        if next_buy < buy_price
            vidx, pidx = vidx + 1, pidx + 1
        elseif (next_sell - buy_price) / buy_price
            buy_signals[buy_idx] = true
            sell_signals[pidxs[pidx+1]] = true
            vidx, pidx = vidx + 2, pidx + 2
        end
    end
end=#
