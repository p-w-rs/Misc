# Train.jl
using Lux, ComponentArrays, Optimisers, Zygote, Random, MLUtils
using ProgressMeter, StatsBase, LinearAlgebra

include("DataPrep.jl")
using .DataPrep

# Define Globals
rng = Xoshiro()
Random.seed!(rng, 10)
PERIOD = 48
BATCH_SIZE = 256

# Get Data, Model, Parameters, Optimizer
xs1, xs2, ys, states, prices = get_data(PERIOD)
loader = DataLoader((xs1, xs2, ys), batchsize=BATCH_SIZE, shuffle=true)
x1, x2, y = first(loader)
model = Chain(
    Parallel(+,
        Chain(
            Conv((size(x1, 1), 2), 1 => 32; stride=2), BatchNorm(32, tanh), Dropout(0.2),
            Conv((1, 2), 32 => 64; stride=2), BatchNorm(64, tanh), Dropout(0.2),
            Conv((1, 2), 64 => 128; stride=2), BatchNorm(128, tanh), Dropout(0.2),
            Conv((1, 2), 128 => 256; stride=2), BatchNorm(256, tanh), Dropout(0.2),
            GlobalMaxPool(), FlattenLayer(),
            Dense(256, 128), BatchNorm(128, tanh), Dropout(0.3),
            Dense(128, 64)
        ),
        Dense(size(x2, 1), 64)
    ), BatchNorm(64, tanh), Dropout(0.3),
    Dense(64, 32), BatchNorm(32, tanh), Dropout(0.3),
    Dense(32, 3)
)
ps, st = Lux.setup(rng, model)
ps = ComponentArray(ps)
opt = Optimisers.setup(Optimisers.Adam(0.0001f0), ps)
logitcrossentropy(ŷ, y; dims=1, agg=mean) = agg(.-sum(y .* logsoftmax(ŷ; dims=dims); dims=dims))

# Define class weights (higher weight = model cares more about that class)
CLASS_WEIGHTS = reshape(Float32[5.0, 5.0, 0.1], 3, 1)  # Class 1 and 2 are 4x more important than class 3

# Modified weighted cross-entropy loss
function weighted_logitcrossentropy(ŷ, y; dims=1, agg=mean)
    weighted_loss = CLASS_WEIGHTS .* (-sum(y .* logsoftmax(ŷ; dims=dims); dims=dims))
    return agg(weighted_loss)
end

#=for i in 10:20
    rng = Xoshiro()
    Random.seed!(rng, i)
    ps, st = Lux.setup(rng, model)
    st = Lux.testmode(st)
    y_hat, _ = model((xs1, xs2), ps, st)
    classes = argmax(y_hat, dims=1)
    classes = map(index -> index.I[1], classes)
    cnt1 = sum(classes .== 1)
    cnt2 = sum(classes .== 2)
    cnt3 = sum(classes .== 3)
    println("$i --- ", cnt1, ":", cnt2, ":", cnt3)
end=#

function accuracy(loader, model, ps, st)
    correct = 0
    total = 0
    for (x1, x2, y) in loader
        y_hat, _ = model((x1, x2), ps, st)
        correct += sum(argmax(y_hat, dims=1) .== argmax(y, dims=1))
        total += size(y, 2)
    end
    return correct / total
end

function test(states, prices, model, ps, st)
    usd = 1000.0
    btc = 0.0
    fee = 0.005
    p = zeros(Float32, 2, 1)
    p[:, 1] .= [0.0f0, 1.0f0]
    for i in 1:size(states, 1)
        s = states[:, :, :, i:i]
        y, _ = model((s, p), ps, st)
        a = argmax(y[:], dims=1)[1]
        open = prices[PERIOD+i, 1]
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

    st = Lux.trainmode(st)
    @showprogress for (i, (x1, x2, y)) in enumerate(loader)
        grads = Zygote.gradient(ps, st) do ps, st
            y_hat, _ = model((x1, x2), ps, st)
            loss = logitcrossentropy(y_hat, y)
        end
        push!(losses, loss)
        opt, ps = Optimisers.update(opt, ps, grads[1])
    end

    st = Lux.testmode(st)
    acc = accuracy(loader, model, ps, st)
    if acc > 0.7
        roi = test(states, prices, model, ps, st)
    else
        roi = 0.0
    end
    println("Epoch: $epoch")
    println("Loss: $(mean(losses)), Accuracy: $acc, ROI: $roi")
end
