# DataPrep.jl

module DataPrep

export create_data_loader

using CSV, DataFrames, Dates, StatsBase, OneHotArrays, MLUtils

include("Simulate.jl")
using .Simulate

function column_zscore(matrix::Matrix)
    mn = mean(matrix, dims=1)
    stddev = std(matrix, dims=1)
    return (matrix .- mn) ./ stddev
end

function state_data(period, df)
    nsamples = length(period:size(df, 1)-1)
    features = size(df, 2) - 2
    states = zeros(Float32, features, period, 1, nsamples)
    mxv = maximum(df[:, :volume])
    mxt = maximum(df[:, :trades])
    for (i, j) in enumerate(period:size(df, 1)-1)
        x = Matrix(df[j-period+1:j, 3:end])
        x[:, 1:4] .= column_zscore(x[:, 1:4])
        x[:, 5] .= x[:, 5] ./ mxv
        x[:, 6] .= x[:, 6] ./ mxt
        states[:, :, :, i] .= x'
    end
    return states
end

function smooth(actions)
    for i in 2:length(actions)-1
        prev = actions[i-1]
        next = actions[i+1]
        if prev == next
            actions[i] = prev
        end
    end
    return actions
end

# positon 1 -> have BTC, position 2 -> have USD
function action_data(period, look_ahead, init_p, matrix)
    nsamples = length(period:size(matrix, 1)-1)
    positions = zeros(Int, nsamples)
    actions = zeros(Int, nsamples)
    offset, idx, lookn, position, prev_p, value = 0, period, look_ahead, init_p, init_p == 1 ? :buy_hold : :sell_usd, 1000.0
    while true
        lookn == 0 && break
        node = simulate(matrix, idx, value, lookn, position == 2, prev_p)
        temp_actions = get_actions(node)
        len = length(temp_actions)
        actions[offset+1:offset+len] .= temp_actions
        offset += len
        idx += len
        position = temp_actions[end]
        prev_p = temp_actions[end-1] == 1 ? :buy_hold : :sell_usd
        if offset > nsamples
            break
        else
            lookn = min(lookn, nsamples - offset)
        end
    end
    positions[1] = 2
    positions[2:end] .= actions[1:end-1]
    return onehotbatch(positions, 1:2), onehotbatch(actions, 1:2)
end

function create_data_loader(period=30, batch_size=128)
    df = CSV.read("Data/1HRS.csv", DataFrame)

    # Train data
    train_idxs = 1:size(df, 1)-div(365,2)*24
    train_df = df[train_idxs, :]
    matrix = Matrix(train_df[:, [:open, :close]])

    states = state_data(period, train_df)
    states = reshape(states, size(states, 1), size(states, 2), size(states, 4))
    states = cat(states, states, dims=3)

    positions, actions = action_data(period, 24, 1, matrix)
    positions, actions = Float32.(positions), Float32.(actions)

    p, a = action_data(period, 24, 2, matrix)
    p, a = Float32.(p), Float32.(a)

    positions = cat(positions, p, dims=2)
    actions = cat(actions, a, dims=2)

    # Test data
    test_idxs = size(df, 1)-div(365,2)*24+1:size(df, 1)
    test_df = df[test_idxs, :]
    matrix = Matrix(test_df[:, [:open, :close]])
    test_states = state_data(period, test_df)
    test_states = reshape(test_states, size(test_states, 1), size(test_states, 2), size(test_states, 4))
    test_positions = rand(1:2, size(test_states, 3))
    test_positions = Float32.(onehotbatch(test_positions, 1:2))

    return DataLoader(
        (states, positions, actions),
        batchsize=batch_size, shuffle=true
    ), test_states, test_positions, test_df
end

end # module
