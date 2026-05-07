# frozen_string_literal: true

module Billing
  # Format minor-unit integer amounts (Stripe's native form — pence,
  # cents, kuruş) into human-readable money strings. Stripe always
  # quotes amounts as smallest-unit integers; the host's price tag
  # never says "12.99" — it says "1299" for USD/GBP/EUR or "1299" for
  # JPY (which has no minor unit).
  #
  #   format_money(1299, "GBP") # => "£12.99"
  #   format_money(1299, "JPY") # => "¥1299"
  #
  # Hosts can override the symbol map by reopening this module in an
  # initializer or monkey-patching SYMBOLS.
  module CurrencyHelper
    SYMBOLS = {
      "USD" => "$",
      "GBP" => "£",
      "EUR" => "€",
      "JPY" => "¥",
      "CAD" => "$",
      "AUD" => "$"
    }.freeze

    # Currencies with no minor unit (Stripe's "zero-decimal currencies").
    # Source: https://docs.stripe.com/currencies#zero-decimal
    ZERO_DECIMAL = %w[BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF UGX VND VUV XAF XOF XPF].freeze

    module_function

    def format_money(amount_in_minor_units, currency_code)
      code   = currency_code.to_s.upcase
      symbol = SYMBOLS[code] || "#{code} "

      if ZERO_DECIMAL.include?(code)
        "#{symbol}#{amount_in_minor_units.to_i}"
      else
        major   = amount_in_minor_units.to_i / 100.0
        decimal = format("%.2f", major)
        "#{symbol}#{decimal}"
      end
    end
  end
end
