module CoinAPI

export get_crypto_historical

using HTTP, JSON, Dates

const COINAPI_API_KEY = "E35AA2F0-2DFA-4C1F-A390-2D87F36DC03F"
const COINAPI_BASE_URL = "https://rest.coinapi.io/v1"

"""
    get_crypto_historical(
        symbol_id::String,
        period_id::String,
        time_start::Union{DateTime,String},
        time_end::Union{DateTime,String},
        limit::Int=100
    ) -> Vector{Dict}

Fetch historical OHLCV data for a cryptocurrency using CoinAPI.

Parameters:
- symbol_id: The symbol ID in CoinAPI format (e.g., "BITSTAMP_SPOT_BTC_USD")
- period_id: Time period of the candles (e.g., "1DAY", "1HRS", "5MIN")
- time_start: Start time for the data (DateTime or ISO8601 string)
- time_end: End time for the data (DateTime or ISO8601 string)
- limit: Number of candles to return (default: 100, max: 100000)

Returns:
- Vector of Dictionaries containing historical OHLCV data
"""
function get_crypto_historical(;
    symbol_id::String="BITSTAMP_SPOT_BTC_USD",
    period_id::String="1DAY",
    time_start::Union{DateTime,String}=now() - Dates.Year(1),
    time_end::Union{DateTime,String}=now(),
    limit::Int=100
)::Vector{Dict}
    url = "$COINAPI_BASE_URL/ohlcv/$symbol_id/history"
    params = Dict(
        "period_id" => period_id,
        "time_start" => string(time_start),
        "time_end" => string(time_end),
        "limit" => string(limit)
    )
    query_string = join(["$k=$(HTTP.escapeuri(v))" for (k, v) in params], "&")
    full_url = "$url?$query_string"
    headers = Dict("Accept" => "text/plain", "X-CoinAPI-Key" => COINAPI_API_KEY)

    try
        response = HTTP.get(full_url, headers=headers)
        if response.status == 200
            return JSON.parse(String(response.body))
        else
            error("API request failed with status code: $(response.status)")
        end
    catch e
        error("Error fetching historical crypto data: $e")
    end
end

end # module
