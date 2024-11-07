# AlphaVantage.jl

module AlphaVantage

export get_news_sentiment, get_crypto_daily, get_currency_exchange_rate

using HTTP, JSON

const API_KEY = "O8QMM4BC6SOM9PVZ"
const BASE_URL = "https://www.alphavantage.co/query"

"""
    get_news_sentiment(;
        tickers::Union{String,Vector{String},Nothing}=nothing,
        topics::Union{String,Vector{String},Nothing}=nothing,
        time_from::Union{String,Nothing}=nothing,
        time_to::Union{String,Nothing}=nothing,
        sort::String="LATEST",
        limit::Int=50
    ) -> Dict

Fetch news and sentiment data from Alpha Vantage API.

Parameters:
- tickers: Optional single ticker or list of stock/crypto/forex symbols (e.g., "IBM" or "IBM,COIN,CRYPTO:BTC" or ["IBM","COIN","CRYPTO:BTC"])
- topics: Optional single topic or list of topics (e.g., "technology" or "technology,earnings" or ["technology","earnings"])
- time_from: Optional start time in format "YYYYMMDDTHHMM"
- time_to: Optional end time in format "YYYYMMDDTHHMM"
- sort: Sort order ("LATEST", "EARLIEST", or "RELEVANCE")
- limit: Number of results to return (1-1000)

Returns:
- Dictionary containing the API response with news items and sentiment data
"""
function get_news_sentiment(;
    tickers::Union{String,Vector{String},Nothing}=nothing,
    topics::Union{String,Vector{String},Nothing}=nothing,
    time_from::Union{String,Nothing}=nothing,
    time_to::Union{String,Nothing}=nothing,
    sort::String="LATEST",
    limit::Int=50
)::Dict
    params = Dict(
        "function" => "NEWS_SENTIMENT",
        "apikey" => API_KEY
    )

    if isa(tickers, String)
        params["tickers"] = tickers
    elseif isa(tickers, Vector{String})
        params["tickers"] = join(tickers, ",")
    end
    if isa(topics, String)
        params["topics"] = topics
    elseif isa(topics, Vector{String})
        params["topics"] = join(topics, ",")
    end
    if !isnothing(time_from)
        params["time_from"] = time_from
    end
    if !isnothing(time_to)
        params["time_to"] = time_to
    end
    params["sort"] = sort
    params["limit"] = string(limit)

    query_string = join(["$k=$(HTTP.escapeuri(v))" for (k, v) in params], "&")
    url = "$BASE_URL?$query_string"

    try
        response = HTTP.get(url)
        if response.status == 200
            return JSON.parse(String(response.body))
        else
            error("API request failed with status code: $(response.status)")
        end
    catch e
        error("Error fetching news sentiment data: $e")
    end
end


"""
    get_crypto_daily(
        symbol::String,
        market::String="USD"
    ) -> Dict

Fetch daily historical time series for a digital currency traded on a specific market.

Parameters:
- symbol: The digital/crypto currency symbol (e.g., "BTC" for Bitcoin)
- market: The exchange market of your choice (e.g., "USD", "EUR")

Returns:
- Dictionary containing daily historical data including:
  - open/high/low/close prices
  - volume
  - market cap
  All values are quoted in both the market-specific currency and USD
"""
function get_crypto_daily(symbol::String, market::String="USD")::Dict
    params = Dict(
        "function" => "DIGITAL_CURRENCY_DAILY",
        "symbol" => symbol,
        "market" => market,
        "apikey" => API_KEY
    )

    query_string = join(["$k=$(HTTP.escapeuri(v))" for (k, v) in params], "&")
    url = "$BASE_URL?$query_string"

    try
        response = HTTP.get(url)
        if response.status == 200
            return JSON.parse(String(response.body))
        else
            error("API request failed with status code: $(response.status)")
        end
    catch e
        error("Error fetching crypto daily data: $e")
    end
end

"""
    get_currency_exchange_rate(
        from_currency::String,
        to_currency::String
    ) -> Dict

Fetch realtime exchange rate for any pair of digital currency (e.g., Bitcoin) or physical currency (e.g., USD).

Parameters:
- from_currency: The currency to get the exchange rate for. Can be physical or digital/crypto currency (e.g., "USD", "BTC")
- to_currency: The destination currency for the exchange rate. Can be physical or digital/crypto currency (e.g., "USD", "BTC")

Returns:
- Dictionary containing the current exchange rate data
"""
function get_currency_exchange_rate(from_currency::String, to_currency::String)::Dict
    params = Dict(
        "function" => "CURRENCY_EXCHANGE_RATE",
        "from_currency" => from_currency,
        "to_currency" => to_currency,
        "apikey" => API_KEY
    )

    query_string = join(["$k=$(HTTP.escapeuri(v))" for (k, v) in params], "&")
    url = "$BASE_URL?$query_string"

    try
        response = HTTP.get(url)
        if response.status == 200
            return JSON.parse(String(response.body))
        else
            error("API request failed with status code: $(response.status)")
        end
    catch e
        error("Error fetching exchange rate data: $e")
    end
end

end # module
