# Train.jl

using Lux, ComponentArrays, Optimisers, Zygote, Random
using ProgressMeter, StatsBase, LinearAlgebra

include("DataPrepDQN.jl")
using .DataPrep

# Define Globals
PERIOD = 3*24
BATCH_SIZE = 1024
γ = 0.99f0
τ = 0.1f0

# Model, Parameters, Optimizer
loader, states, candles = create_data_loader(PERIOD, BATCH_SIZE)
s, p, a, r, ns, np, t = first(loader)
model = Chain(
    Parallel(+,
        Chain(
            Recurrence(LSTMCell(size(s, 1) => 64; train_state=true), return_sequence=true),
            Recurrence(LSTMCell(64 => 32; train_state=true)),
            Dense(32, 32), BatchNorm(32, tanh),
            Dense(32, 32)
        ),
        Dense(size(p, 1), 32)
    ), BatchNorm(32, tanh),
    Dense(32, 2)
)
model = Chain(
    Parallel(+,
        Chain(
            Conv((size(s, 1), 2), 1 => 32; stride=2), BatchNorm(32, tanh),
            Conv((1, 2), 32 => 64; stride=2), BatchNorm(64, tanh),
            Conv((1, 2), 64 => 128; stride=2), BatchNorm(128, tanh),
            Conv((1, 2), 128 => 256; stride=2), BatchNorm(256, tanh),
            GlobalMaxPool(), FlattenLayer(),
            Dense(256, 128), BatchNorm(128, tanh),
            Dense(128, 64)
        ),
        Dense(size(p, 1), 64)
    ), BatchNorm(64, tanh),
    Dense(64, 32), BatchNorm(32, tanh),
    Dense(32, 2)
)
rng = Xoshiro()
Random.seed!(rng, 3)
ps, st = Lux.setup(rng, model)
ps = ComponentArray(ps)
tps, tst = deepcopy(ps), deepcopy(st)
opt = Optimisers.setup(Optimisers.Adam(0.0001f0), ps)
#=bss = []
@showprogress for i in 1:100
    rng = Xoshiro()
    Random.seed!(rng, i)
    ps, st = Lux.setup(rng, model)
    ps = ComponentArray(ps)
    tps, tst = deepcopy(ps), deepcopy(st)
    opt = Optimisers.setup(Optimisers.Adam(0.0001f0), ps)
    st, tst = Lux.testmode(st), Lux.testmode(tst)
    roi, buy_sell = test(candles, states, model, ps, st)
    println(i, " Buy/Sell: ", buy_sell)
    push!(bss, buy_sell)
end
mx = 0
mx_i =0
for (i, v) in enumerate(bss)
    if sum(v) > mx
        mx = sum(v)
        mx_i = i
    end
end=#

function test(df, states, model, ps, st)
    buy_sell = [0, 0]
    usd = 1000.0
    btc = 0.0
    fee = 0.005
    p = zeros(Float32, 2, 1)
    p[:, 1] .= [0.0f0, 1.0f0]
    for i in 1:size(df, 1)-PERIOD
        s = states[:, :, :, i:i]
        q, _ = model((s, p), ps, st)
        a = argmax(q[:], dims=1)[1]
        open = df[PERIOD+i, :open]
        #println("Action: ", q, " BTC: $btc", " USD: $usd")
        if a == 1 && usd > 0.0
            btc = (usd * (1 - fee)) / open
            usd = 0.0
            p[:, 1] .= [1.0f0, 0.0f0]
            buy_sell[1] += 1
            #println("Buy: $open", " BTC: $btc", " USD: $usd")
        elseif a == 2 && btc > 0.0
            usd = btc * open * (1 - fee)
            btc = 0.0
            p[:, 1] .= [0.0f0, 1.0f0]
            buy_sell[2] += 1
            #println("Sell: $open", " BTC: $btc", " USD: $usd")
        end
    end
    value = usd + (btc * max(df[end, :close], df[end, :open]))
    return (value - 1000.0) / 1000.0, buy_sell
end

# Train the Model
best_roi = -Inf
best_ps, best_st = deepcopy(ps), deepcopy(st)
for epoch in 1:1000
    global model, ps, st, tps, tst, opt
    global best_roi, best_ps, best_st
    global loss, losses = 0.0, Float32[]

    st, tst = Lux.trainmode(st), Lux.trainmode(tst)
    @showprogress for (i, (s, p, a, r, ns, np, t)) in enumerate(loader)
        grads = Zygote.gradient(ps, st) do ps, st
            Qs, _ = model((s, p), ps, st)
            Q = sum(Qs .* a, dims=1)
            Qs_prime, _ = model((ns, np), tps, tst)
            Q_prime = maximum(Qs_prime, dims=1)
            target = r .+ (γ .* Q_prime .* (1.0f0 .- t))
            loss = sum((Q .- target) .^ 2) + norm(ps, 2)
        end
        push!(losses, loss)
        opt, ps = Optimisers.update(opt, ps, grads[1])
    end
    tps .= τ .* ps .+ (1 - τ) .* tps

    st, tst = Lux.testmode(st), Lux.testmode(tst)
    roi, buy_sell = test(candles, states, model, ps, st)
    println("Epoch: $epoch, Loss: $(mean(losses)), ROI: $roi, Buy/Sell: $buy_sell")
end
