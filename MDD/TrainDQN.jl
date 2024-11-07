# Train.jl
using Lux, ComponentArrays, Optimisers, Zygote, Random, MLUtils
using ProgressMeter, StatsBase, LinearAlgebra

include("DataPrepDQN.jl")
using .DataPrep

# Define Globals
rng = Xoshiro()
Random.seed!(rng, 10)
PERIOD = 48
BATCH_SIZE = 256
γ = 0.99f0
τ = 0.1f0

# Get Data, Model, Parameters, Optimizer
prices, states, nxt_states, positions, nxt_positions, actions, rewards, terminals = get_data(PERIOD)
loader = DataLoader((states, nxt_states, positions, nxt_positions, actions, rewards, terminals), batchsize=BATCH_SIZE, shuffle=true)
(s, ns, p, np, a, r, t) = first(loader)
model = Chain(
    Parallel(+,
        Chain(
            Conv((size(s, 1), 2), 1 => 32; stride=2), BatchNorm(32, tanh), Dropout(0.2),
            Conv((1, 2), 32 => 64; stride=2), BatchNorm(64, tanh), Dropout(0.2),
            Conv((1, 2), 64 => 128; stride=2), BatchNorm(128, tanh), Dropout(0.2),
            Conv((1, 2), 128 => 256; stride=2), BatchNorm(256, tanh), Dropout(0.2),
            GlobalMaxPool(), FlattenLayer(),
            Dense(256, 128), BatchNorm(128, tanh), Dropout(0.3),
            Dense(128, 64)
        ),
        Dense(size(p, 1), 64)
    ), BatchNorm(64, tanh), Dropout(0.3),
    Dense(64, 32), BatchNorm(32, tanh), Dropout(0.3),
    Dense(32, 3)
)
ps, st = Lux.setup(rng, model)
ps = ComponentArray(ps)
tps, tst = deepcopy(ps), deepcopy(st)
opt = Optimisers.setup(Optimisers.Adam(0.0001f0), ps)

function test(states, prices, model, ps, st)
    usd = 1000.0
    btc = 0.0
    fee = 0.005
    p = zeros(Float32, 2, 1)
    p[:, 1] .= [0.0f0, 1.0f0]
    for i in 1:div(size(states, 1), 4)
        s = states[:, :, :, i:i]
        q, _ = model((s, p), ps, st)
        a = argmax(q[:], dims=1)[1]
        open = prices[PERIOD+i, 1]
        if a == 1 && usd > 0.0
            btc = (usd * (1 - fee)) / open
            usd = 0.0
            p[:, 1] .= [1.0f0, 0.0f0]
        elseif a == 2 && btc > 0.0
            usd = btc * open * (1 - fee)
            btc = 0.0
            p[:, 1] .= [0.0f0, 1.0f0]
        else
        println(a, " ", usd, " ", btc)
        end
    end
    value = usd + (btc * max(prices[end, 1], prices[end, 2]))
    return (value - 1000.0) / 1000.0
end

# Train the Model
best_roi = -Inf
best_ps, best_st = deepcopy(ps), deepcopy(st)
for epoch in 1:1000
    global model, ps, st, opt
    global best_roi, best_ps, best_st
    global loss, losses = 0.0, Float32[]

    st, tst = Lux.trainmode(st), Lux.trainmode(tst)
    @showprogress for (i, (s, ns, p, np, a, r, t)) in enumerate(loader)
        grads = Zygote.gradient(ps, st) do ps, st
            Qs, _ = model((s, p), ps, st)
            Q = sum(Qs .* a, dims=1)
            Qs_prime, _ = model((ns, np), tps, tst)
            Q_prime = maximum(Qs_prime, dims=1)
            target = r .+ (γ .* Q_prime .* (1.0f0 .- t))
            loss = sum((Q .- target) .^ 2)
        end
        push!(losses, loss)
        opt, ps = Optimisers.update(opt, ps, grads[1])
    end
    tps .= τ .* ps .+ (1 - τ) .* tps

    st, tst = Lux.testmode(st), Lux.testmode(tst)
    roi = test(states, prices, model, ps, st)
    println("Epoch: $epoch")
    println("Loss: $(mean(losses)), ROI: $roi")
end
