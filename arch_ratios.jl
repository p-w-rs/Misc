function fibonacci(n::Int)
    if n <= 1
        return [BigInt(i) for i in 0:n]
    end

    fib = Vector{BigInt}(undef, n + 1)
    fib[1] = 0
    fib[2] = 1

    for i in 3:n+1
        fib[i] = fib[i-1] + fib[i-2]
    end

    return fib
end

function fibmap(n, m)
    seq = fibonacci(n + 1)[2:end]
    base = div(m, seq[n])
    fib = seq .* base
    return fib
end

function fibmapf(n, m)
    seq = fibonacci(n + 1)[2:end]
    base = m / seq[n]
    fib = seq .* base
    return fib
end
