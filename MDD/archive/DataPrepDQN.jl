# DataPrep.jl

module DataPrep

export create_data_loader

using CSV, DataFrames, Dates, StatsBase, MLUtils

function column_zscore(matrix::Matrix)
    mn = mean(matrix, dims=1)
    stddev = std(matrix, dims=1)
    return (matrix .- mn) ./ stddev
end

function state_data(period, df)
    nsamples = length(period:size(df, 1)-1)
    features = size(df, 2)-2
    states = zeros(Float32, features, period, 1, nsamples)
    next_states = zeros(Float32, features, period, 1, nsamples)
    mxv = maximum(df[:, :volume])
    mxt = maximum(df[:, :trades])
    for (i, j) in enumerate(period:size(df, 1)-1)
        x = Matrix(df[j-period+1:j, 3:end])
        x[:, 1:6] .= column_zscore(x[:, 1:6])
        x[:, end-2:end] .= column_zscore(x[:, end-2:end])
        states[:, :, :, i] .= x'

        x = Matrix(df[j+1-period+1:j+1, 3:end])
        x[:, 1:6] .= column_zscore(x[:, 1:6])
        x[:, end-2:end] .= column_zscore(x[:, end-2:end])
        next_states[:, :, :, i] .= x'
    end
    return states, next_states
end

# positon 1 -> have BTC, position 2 -> have USD
# action 1 -> buy BTC, action 2 -> sell BTC
function pos_act_rew_data(period, df, position, action)
    nsamples = length(period:size(df, 1)-1)
    positions = zeros(Float32, 2, nsamples)
    next_positions = zeros(Float32, 2, nsamples)
    positions[position, :] .= 1.0
    next_positions[action, :] .= 1.0

    actions = zeros(Float32, 2, nsamples)
    actions[action, :] .= 1.0

    rewards = zeros(Float32, 1, nsamples)
    terminals = zeros(Float32, 1, nsamples)
    for (i, j) in enumerate(period:size(df, 1)-1)
        open = df[j+1, "open"]
        close = df[j+1, "close"]
        roi = (close - open) / open
        if action == 1 && position == 1
            rewards[:, i] .+= roi
        elseif action == 1 && position == 2
            rewards[:, i] .-= 0.005
            rewards[:, i] .+= roi
        elseif action == 2 && position == 1
            rewards[:, i] .-= 0.005
            rewards[:, i] .-= roi
        elseif action == 2 && position == 2
            rewards[:, i] .-= roi
        end

        current_date = df[j, :open_time]
        next_date = df[j+1, :open_time]
        if week(current_date) != week(next_date)
            terminals[:, i] .= 1.0
        end
    end
    return positions, next_positions, actions, rewards, terminals
end

function create_data_loader(period=30, batch_size=128)
    df = CSV.read("Data/1HRS.csv", DataFrame)
    testn = 90*24
    test_df = df[end-testn+1:end, :]
    train_df = df[1:end-testn, :]

    ### TRAIN DATA ###
    # position is BTC, Action is buy
    states, next_states = state_data(period, train_df)
    positions, next_positions, actions, rewards, terminals =
        pos_act_rew_data(period, train_df, 1, 1)

    # position is USD, Action is buy
    p, np, a, r, t = pos_act_rew_data(period, train_df, 2, 1)
    positions = cat(positions, p, dims=2)
    actions = cat(actions, a, dims=2)
    rewards = cat(rewards, r, dims=2)
    next_positions = cat(next_positions, np, dims=2)
    terminals = cat(terminals, t, dims=2)

    # position is BTC, Action is sell
    p, np, a, r, t = pos_act_rew_data(period, train_df, 1, 2)
    positions = cat(positions, p, dims=2)
    actions = cat(actions, a, dims=2)
    rewards = cat(rewards, r, dims=2)
    next_positions = cat(next_positions, np, dims=2)
    terminals = cat(terminals, t, dims=2)

    # position is USD, Action is sell
    p, np, a, r, t = pos_act_rew_data(period, train_df, 2, 2)
    positions = cat(positions, p, dims=2)
    actions = cat(actions, a, dims=2)
    rewards = cat(rewards, r, dims=2)
    next_positions = cat(next_positions, np, dims=2)
    terminals = cat(terminals, t, dims=2)

    states = cat(states, states, states, states, dims=4)
    next_states = cat(next_states, next_states, next_states, next_states, dims=4)
    #states = reshape(states, size(states, 1), size(states, 2), size(states, 4))
    #next_states = reshape(next_states, size(next_states, 1), size(next_states, 2), size(next_states, 4))

    ### TEST DATA ###
    test_states, _ = state_data(period, test_df)
    #test_states = reshape(test_states, size(test_states, 1), size(test_states, 2), size(test_states, 4))
    return DataLoader(
        (states, positions, actions, rewards, next_states, next_positions, terminals),
        batchsize=batch_size, shuffle=true
    ), test_states, test_df
end

end # module
