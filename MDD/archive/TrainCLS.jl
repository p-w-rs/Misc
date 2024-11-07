# Train.jl
using Lux, ComponentArrays, Optimisers, Zygote, Random
using ProgressMeter, StatsBase

include("DataPrepCLS.jl")
using .DataPrep

# Define Globals
PERIOD = 48
BATCH_SIZE = 256

# Get Data, Model, Parameters, Optimizer
loader, states, positions, candles = create_data_loader(PERIOD, BATCH_SIZE)
s, p, a = first(loader)
model = Chain(
    Parallel(+,
        Chain(
            Recurrence(LSTMCell(size(s, 1) => 64; train_state=true), return_sequence=true),
            Recurrence(LSTMCell(64 => 128; train_state=true)),
            Dense(128, 64), BatchNorm(64, tanh),
            Dense(64, 32)
        ),
        Dense(size(p, 1), 32)
    ), BatchNorm(32, tanh),
    Dense(32, 2)
)
rng = Xoshiro()
Random.seed!(rng, 3)
ps, st = Lux.setup(rng, model)
ps = ComponentArray(ps)
opt = Optimisers.setup(Optimisers.Adam(0.0001f0), ps)
logitcrossentropy(ŷ, y; dims=1, agg=mean) = agg(.-sum(y .* logsoftmax(ŷ; dims=dims); dims=dims))
#=st = Lux.testmode(st)
a, _ = model((states, positions), ps, st)
mx = argmax(a, dims=1)
cnt1 = 0
cnt2 = 0
for m in mx
    if m.I[1] == 1
        cnt1 += 1
    else
        cnt2 += 1
    end
end
println(cnt1, ":", cnt2)=#

function accuracy(loader, model, ps, st)
    correct = 0
    total = 0
    for (s, p, a) in loader
        a_hat, _ = model((s, p), ps, st)
        a_hat = argmax(a_hat, dims=1)
        a = argmax(a, dims=1)
        correct += sum(a .== a_hat)
        total += size(a, 2)
    end
    return correct / total
end

function test(df, states, model, ps, st)
    usd = 1000.0
    btc = 0.0
    fee = 0.005
    p = zeros(Float32, 2, 1)
    p[:, 1] .= [0.0f0, 1.0f0]
    for i in 1:size(df, 1)-PERIOD
        s = states[:, :, i:i]
        a, _ = model((s, p), ps, st)
        a = argmax(a[:], dims=1)[1]
        open = df[PERIOD+i, :open]
        if a == 1 && usd > 0.0
            btc = (usd * (1 - fee)) / open
            usd = 0.0
            p[:, 1] .= [1.0f0, 0.0f0]
        elseif a == 2 && btc > 0.0
            usd = btc * open * (1 - fee)
            btc = 0.0
            p[:, 1] .= [0.0f0, 1.0f0]
        end
    end
    value = usd + (btc * max(df[end, :close], df[end, :open]))
    return (value - 1000.0) / 1000.0
end

# Train the Model
best_roi = -Inf
best_ps, best_st = deepcopy(ps), deepcopy(st)
for epoch in 1:1000
    global model, ps, st, opt
    global best_roi, best_ps, best_st
    global loss, losses = 0.0, Float32[]

    st = Lux.trainmode(st)
    for (i, (s, p, a)) in enumerate(loader)
        grads = Zygote.gradient(ps, st) do ps, st
            a_hat, _ = model((s, p), ps, st)
            loss = logitcrossentropy(a_hat, a)
        end
        push!(losses, loss)
        opt, ps = Optimisers.update(opt, ps, grads[1])
    end

    st = Lux.testmode(st)
    acc = accuracy(loader, model, ps, st)
    roi = test(candles, states, model, ps, st)
    println("Epoch: $epoch")
    println("Loss: $(mean(losses)), Accuracy: $acc, ROI: $roi")
end
