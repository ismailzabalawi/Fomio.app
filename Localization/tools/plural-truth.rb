# Integer plural categories for every Discourse client locale, computed with Discourse's own CLDR lambdas.
# Usage: ruby Localization/tools/plural-truth.rb <discourse>/config/locales/plurals.rb "<locales>" > table.json
require "json"
rules = eval(File.read(ARGV[0]))
locales = ARGV[1].split
counts = (0..200).to_a + [1000, 1001, 1002, 1003, 1011, 1100, 10_000, 100_000, 1_000_000]
out = {}
locales.each do |loc|
  entry = rules[loc.to_sym] || rules[loc.split("_").first.to_sym]
  key = rules[loc.to_sym] ? loc : loc.split("_").first
  unless entry
    out[loc] = { "rules_key" => nil }
    next
  end
  p = entry[:i18n][:plural]
  out[loc] = { "rules_key" => key, "keys" => p[:keys].map(&:to_s), "categories" => counts.to_h { |n| [n.to_s, p[:rule].call(n).to_s] } }
end
puts JSON.pretty_generate(out)
