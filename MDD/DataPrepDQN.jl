# DataPrep.jl
module DataPrep

export get_data

using CSV, DataFrames, Dates, StatsBase, OneHotArrays
using ProgressMeter, StatsBase, Random

const MAKER_FEE = 0.004
const TAKER_FEE = 0.006

function column_zscore(matrix::Matrix)
    mn = mean(matrix, dims=1)
    stddev = std(matrix, dims=1)
    return (matrix .- mn) ./ stddev
end

function positions_actions(df, position, action, period)
    nsamples = length(period:size(df, 1)-1)
    positions = ones(Int, nsamples) .* position
    nxt_positions = ones(Int, nsamples)
    actions = ones(Int, nsamples) .* action
    rewards = zeros(Float32, 1, nsamples)
    terminals = zeros(Float32, 1, nsamples)

    open = df[period+1:end, "open"]
    close = df[period+1:end, "close"]
    rois = (close .- open) ./ open
    if position == 1 && action == 2
        rewards[:] .-= MAKER_FEE
        rewards[:] .-= rois
        nxt_positions .* 2
    elseif position == 1 && action == 3
        rewards[:] .+= rois
        nxt_positions .* 1
    elseif position == 2 && action == 1
        rewards[:] .-= MAKER_FEE
        rewards[:] .+= rois
        nxt_positions .* 1
    elseif position == 2 && action == 3
        rewards[:] .-= rois
        nxt_positions .* 2
    else
        print("Error")
    end
    terminals[:] .= week.(df[period:end-1, :open_time]) != week.(df[period+1:end, :open_time])
    return positions, nxt_positions, actions, rewards, terminals
end

function get_data(period)
    df = CSV.read("Data/1HRS.csv", DataFrame)
    prices = Matrix(df[:, [:open, :close]])

    nsamples = length(period:size(df, 1)-1)
    features = size(df, 2) - 2
    states = zeros(Float32, features, period, 1, nsamples)
    nxt_states = zeros(Float32, features, period, 1, nsamples)
    for (i, j) in enumerate(period:size(df, 1)-1)
        x = Matrix(df[j-period+1:j, 3:end])
        x[:, 1:6] .= column_zscore(x[:, 1:6])
        states[:, :, :, i] .= x'

        x = Matrix(df[j-period+2:j+1, 3:end])
        x[:, 1:6] .= column_zscore(x[:, 1:6])
        nxt_states[:, :, :, i] .= x'
    end

    # Position 1: BTC, Action 2: Sell
    pos1, npos1, act1, rew1, term1 = positions_actions(df, 1, 2, period)

    # Position 1: BTC, Action 3: None
    pos2, npos2, act2, rew2, term2 = positions_actions(df, 1, 3, period)

    # Position 2: USDT, Action 1: Buy
    pos3, npos3, act3, rew3, term3 = positions_actions(df, 2, 1, period)

    # Position 2: USDT, Action 3: None
    pos4, npos4, act4, rew4, term4 = positions_actions(df, 2, 3, period)

    states = cat(states, states, states, states, dims=4)
    nxt_states = cat(nxt_states, nxt_states, nxt_states, nxt_states, dims=4)
    positions = vcat(pos1, pos2, pos3, pos4)
    positions = Float32.(onehotbatch(positions, 1:2))
    nxt_positions = vcat(npos1, npos2, npos3, npos4)
    nxt_positions = Float32.(onehotbatch(nxt_positions, 1:2))
    actions = vcat(act1, act2, act3, act4)
    actions = Float32.(onehotbatch(actions, 1:3))
    rewards = cat(rew1, rew2, rew3, rew4, dims=2)
    terminals = cat(term1, term2, term3, term4, dims=2)

    return prices, states, nxt_states, positions, nxt_positions, actions, rewards, terminals
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
