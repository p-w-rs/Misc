# DataWrangler.jl

using DataFrames, CSV, Dates

include("AlphaVantage.jl")
using .AlphaVantage

function historical_crypto_data(symbol="BTC", market="USD")
    crypto = get_crypto_daily(symbol, market)
    crypto = crypto["Time Series (Digital Currency Daily)"]
    df = DataFrame(
        date=Vector{Date}(undef, length(crypto)),
        open=Vector{Float64}(undef, length(crypto)),
        high=Vector{Float64}(undef, length(crypto)),
        low=Vector{Float64}(undef, length(crypto)),
        close=Vector{Float64}(undef, length(crypto)),
        volume=Vector{Float64}(undef, length(crypto))
    )
    for (i, k) in enumerate(keys(crypto))
        date = Date(k)
        row = crypto[k]
        df[i, "date"] = date
        df[i, "open"] = parse(Float64, row["1. open"])
        df[i, "high"] = parse(Float64, row["2. high"])
        df[i, "low"] = parse(Float64, row["3. low"])
        df[i, "close"] = parse(Float64, row["4. close"])
        df[i, "volume"] = parse(Float64, row["5. volume"])
    end
    sort!(df)
    CSV.write("Data/$(symbol)_$(market)_daily.csv", df)
    return df
end

function date_encoding_cyclical(dates::Vector{Date})
    # Initialize DataFrame with base features
    df = DataFrame(
        date=dates,
        day_of_year=dayofyear.(dates),
        day_of_month=day.(dates),
        day_of_week=dayofweek.(dates),
        week_of_year=week.(dates),
        week_of_month=map(d -> div(day(d) - 1, 7) + 1, dates),
        month_of_year=month.(dates)
    )

    # Add cyclical encodings
    # Day of year (1-365/366)
    df.day_of_year_sin = sin.(2π * df.day_of_year ./ 365)
    df.day_of_year_cos = cos.(2π * df.day_of_year ./ 365)

    # Day of month (1-31)
    df.day_of_month_sin = sin.(2π * df.day_of_month ./ 31)
    df.day_of_month_cos = cos.(2π * df.day_of_month ./ 31)

    # Day of week (1-7)
    df.day_of_week_sin = sin.(2π * df.day_of_week ./ 7)
    df.day_of_week_cos = cos.(2π * df.day_of_week ./ 7)

    # Week of year (1-52/53)
    df.week_of_year_sin = sin.(2π * df.week_of_year ./ 52)
    df.week_of_year_cos = cos.(2π * df.week_of_year ./ 52)

    # Week of month (1-5)
    df.week_of_month_sin = sin.(2π * df.week_of_month ./ 5)
    df.week_of_month_cos = cos.(2π * df.week_of_month ./ 5)

    # Month of year (1-12)
    df.month_of_year_sin = sin.(2π * df.month_of_year ./ 12)
    df.month_of_year_cos = cos.(2π * df.month_of_year ./ 12)

    CSV.write("Data/$(symbol)_$(market)_date_enc.csv", df)
    return df
end

function main()
    # Fetch historical data for Bitcoin
    df = historical_crypto_data("BTC", "USD")

    # Generate cyclical date features
    date_encoding_cyclical(df.date)
end

main()
