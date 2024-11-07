# DataWrangler.jl

using DataFrames, CSV, Dates

include("CoinAPI.jl")
using .CoinAPI

function cyclical_date_encoding_row(date)
    # Base features
    hour_ = hour(date)
    dayofweek_ = dayofweek(date)
    dayofmonth = day(date)
    dayofyear_ = dayofyear(date)
    weekofyear = week(date)
    weekofmonth = div(day(date) - 1, 7) + 1
    monthofyear = month(date)

    # Cyclical encoding
    hour_sin = sin(2π * hour_ / 24)
    hour_cos = cos(2π * hour_ / 24)
    dayofweek_sin = sin(2π * dayofweek_ / 7)
    dayofweek_cos = cos(2π * dayofweek_ / 7)
    dayofmonth_sin = sin(2π * dayofmonth / 31)
    dayofmonth_cos = cos(2π * dayofmonth / 31)
    dayofyear_sin = sin(2π * dayofyear_ / 365)
    dayofyear_cos = cos(2π * dayofyear_ / 365)
    weekofyear_sin = sin(2π * weekofyear / 52)
    weekofyear_cos = cos(2π * weekofyear / 52)
    weekofmonth_sin = sin(2π * weekofmonth / 5)
    weekofmonth_cos = cos(2π * weekofmonth / 5)
    monthofyear_sin = sin(2π * monthofyear / 12)
    monthofyear_cos = cos(2π * monthofyear / 12)

    return [
        hour_sin, hour_cos, dayofweek_sin, dayofweek_cos,
        dayofmonth_sin, dayofmonth_cos, dayofyear_sin, dayofyear_cos, weekofyear_sin, weekofyear_cos,
        weekofmonth_sin, weekofmonth_cos, monthofyear_sin, monthofyear_cos
    ]
end

function crypto_row(c)
    open_t = DateTime(c["time_period_start"][1:end-5])
    close_t = DateTime(c["time_period_end"][1:end-5])
    open = c["price_open"]
    high = c["price_high"]
    low = c["price_low"]
    close = c["price_close"]
    volume = c["volume_traded"]
    trades = c["trades_count"]
    return [open_t, close_t, open, high, low, close, volume, trades]
end

function willr(high, low, close, period)
    n = length(close)
    result = zeros(n)

    for i in period:n
        highest_high = maximum(high[i-period+1:i])
        lowest_low = minimum(low[i-period+1:i])

        # Williams %R formula: ((Highest High - Close) / (Highest High - Lowest Low)) * -100
        if highest_high != lowest_low
            result[i] = ((highest_high - close[i]) / (highest_high - lowest_low)) * -100
        end
    end

    return result
end

function mfi(high, low, close, volume, period)
    n = length(close)
    result = zeros(n)

    # Calculate typical price
    typical_price = (high .+ low .+ close) ./ 3
    money_flow = typical_price .* volume

    for i in period+1:n
        pos_flow = 0.0
        neg_flow = 0.0

        for j in 1:period
            # Compare current with previous, adjusting indices to avoid 0
            if typical_price[i-j+1] > typical_price[i-j]
                pos_flow += money_flow[i-j+1]
            else
                neg_flow += money_flow[i-j+1]
            end
        end

        if neg_flow != 0
            money_ratio = pos_flow / neg_flow
            result[i] = 100 - (100 / (1 + money_ratio))
        else
            result[i] = 100
        end
    end

    return result
end


function ultosc(high, low, close, period1, period2, period3)
    n = length(close)
    result = zeros(n)

    # Calculate buying pressure (BP) and true range (TR)
    function calc_bp_tr(i)
        true_low = min(low[i], close[i-1])
        true_high = max(high[i], close[i-1])
        bp = close[i] - true_low
        tr = true_high - true_low
        return bp, tr
    end

    # Calculate average for a specific period
    function calc_average(i, period)
        bp_sum = 0.0
        tr_sum = 0.0

        for j in 0:period-1
            bp, tr = calc_bp_tr(i-j)
            bp_sum += bp
            tr_sum += tr
        end

        return tr_sum != 0 ? bp_sum / tr_sum : 0.0
    end

    # Main calculation
    max_period = max(period1, period2, period3)
    for i in max_period+1:n
        avg1 = calc_average(i, period1)
        avg2 = calc_average(i, period2)
        avg3 = calc_average(i, period3)

        # Ultimate Oscillator formula with standard weightings (4,2,1)
        result[i] = 100 * ((4 * avg1 + 2 * avg2 + avg3) / 7)
    end

    return result
end


function historical_crypto_data(period_id="1DAY", time_start=floor(now() - Dates.Year(3), Dates.Day))
    df = DataFrame(
        open_time=DateTime[],
        close_time=DateTime[],
        open=Float64[],
        high=Float64[],
        low=Float64[],
        close=Float64[],
        volume=Float64[],
        trades=Int[],
        hour_sin=Float64[],
        hour_cos=Float64[],
        dayofweek_sin=Float64[],
        dayofweek_cos=Float64[],
        dayofmonth_sin=Float64[],
        dayofmonth_cos=Float64[],
        dayofyear_sin=Float64[],
        dayofyear_cos=Float64[],
        weekofyear_sin=Float64[],
        weekofyear_cos=Float64[],
        weekofmonth_sin=Float64[],
        weekofmonth_cos=Float64[],
        monthofyear_sin=Float64[],
        monthofyear_cos=Float64[]
    )
    crypto = get_crypto_historical(period_id=period_id, time_start=time_start, limit=100000)
    for c in crypto
        candle = crypto_row(c)
        date_enc = cyclical_date_encoding_row(candle[1])
        push!(df, vcat(candle, date_enc))
    end
    sort!(df, :open_time)

    while df.open_time[end] < floor(now(), Dates.Day)
        crypto = get_crypto_historical(period_id=period_id, time_start=df.open_time[end], limit=100000)
        for c in crypto
            candle = crypto_row(c)
            date_enc = cyclical_date_encoding_row(candle[1])
            push!(df, vcat(candle, date_enc))
        end
        sort!(df, :open_time)
    end
    willr_14 = willr(df.high, df.low, df.close, 14)
    mfi_14 = mfi(df.high, df.low, df.close, df.volume, 14)
    ultosc_7_14_28 = ultosc(df.high, df.low, df.close, 7, 14, 28)

    df.willr_14 = willr_14 ./ 100
    df.mfi_14 = mfi_14 ./ 100
    df.ultosc_7_14_28 = ultosc_7_14_28 ./ 100

    CSV.write("Data/$(period_id).csv", df[29:end, :])
    return df
end

historical_crypto_data("1DAY")
historical_crypto_data("1HRS")
