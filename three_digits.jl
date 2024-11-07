function get_digit(x::Int, place::Int)
    # We only need to keep track of digits up to our desired place
    mod_num = 10^(place + 1)

    # Initialize result as 1 (3^0)
    result = 1

    # Compute (3^x mod mod_num) using repeated multiplication
    for _ in 1:x
        result = (result * 3) % mod_num
    end

    # Extract the digit at the desired place
    (result ÷ 10^place) % 10
end

d1s = [get_digit(i, 0) for i in 0:100]
d2s = [get_digit(i, 1) for i in 0:100]

println(d1s)
println(d2s)
