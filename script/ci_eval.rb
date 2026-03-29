#!/usr/bin/env ruby
# frozen_string_literal: true

# CI Evaluation Script
#
# Runs UserDataFetcher 3 times and uses median time for fairness.
# Queries are deterministic (same count every run).
# Does NOT use credits or RunLog — those are local-only mechanics.
#
# Outputs:
#   tmp/eval_result.json  — machine-readable result for leaderboard updater
#   tmp/eval_comment.md   — PR comment markdown

require_relative "../config/environment"
require "json"
require "fileutils"

RUNS = 3

FileUtils.mkdir_p("tmp")

challenge = Challenge.find_by!(slug: "n_plus_one_dashboard")
student   = ENV.fetch("STUDENT_USERNAME", "unknown")
pr_number = ENV.fetch("PR_NUMBER", "0").to_i

puts "=" * 60
puts "Evaluation: @#{student} (PR ##{pr_number})"
puts "Baseline : #{challenge.baseline_queries} queries, #{challenge.baseline_time_ms.round(1)}ms"
puts "=" * 60

# --- Run scorer RUNS times ---
results = RUNS.times.map do |i|
  r = Scorer.run(challenge)
  puts "Run #{i + 1}/#{RUNS}: #{r[:queries]} queries, #{r[:time].round(1)}ms"
  r
rescue => e
  puts "Run #{i + 1}/#{RUNS}: FAILED — #{e.message}"
  nil
end

if results.any?(&:nil?)
  File.write("tmp/eval_comment.md", <<~MD)
    ## ❌ Evaluation Failed — @#{student}

    `UserDataFetcher` çalışırken hata oluştu.
    Lütfen implementation'ınızı kontrol edin ve PR'ı güncelleyin.
  MD
  abort "Scorer failed on at least one run."
end

# Queries: deterministic, use minimum for safety
queries = results.map { |r| r[:queries] }.min

# Time: sort and take median
times   = results.map { |r| r[:time] }.sort
time_ms = times[RUNS / 2]

puts "-" * 60
puts "Queries (min of #{RUNS}): #{queries}"
puts "Time (median of #{RUNS}): #{time_ms.round(1)}ms"

# --- Score calculation ---
# NOTE: previous_run is nil in CI → stability_score = 0 → max 90 pts
score = EvaluationEngine::ScoreCalculator.new(
  challenge:    challenge,
  metrics:      { queries: queries, time: time_ms },
  previous_run: nil
).call

query_pts = (score.query_reduction_pct * EvaluationEngine::ScoreCalculator::QUERY_WEIGHT).round(2)
time_pts  = (score.time_reduction_pct  * EvaluationEngine::ScoreCalculator::TIME_WEIGHT).round(2)

puts "Score: #{score.total_score} / 90"
puts "=" * 60

# --- Write JSON for leaderboard updater ---
result = {
  student:             student,
  pr_number:           pr_number,
  queries:             queries,
  time_ms:             time_ms.round(1),
  baseline_queries:    challenge.baseline_queries,
  baseline_time_ms:    challenge.baseline_time_ms.round(1),
  query_reduction_pct: score.query_reduction_pct,
  time_reduction_pct:  score.time_reduction_pct,
  query_pts:           query_pts,
  time_pts:            time_pts,
  total_score:         score.total_score,
  evaluated_at:        Time.now.utc.iso8601
}

File.write("tmp/eval_result.json", JSON.pretty_generate(result))

# --- Build PR comment markdown ---
def reduction_row(label, baseline, actual, pct, pts)
  improved = actual <= baseline
  emoji    = improved ? "✅" : "❌"
  sign     = pct >= 0 ? "▼" : "▲"
  "| #{label} | #{baseline} | #{emoji} #{actual} | #{sign} #{pct.abs.round(1)}% | #{pts} |"
end

queries_row = reduction_row(
  "Queries", challenge.baseline_queries, queries,
  score.query_reduction_pct, query_pts
)
time_row = reduction_row(
  "Süre (ms)", challenge.baseline_time_ms.round(1), time_ms.round(1),
  score.time_reduction_pct, time_pts
)

top_emoji = if score.total_score >= 70 then "🏆"
elsif score.total_score >= 40 then "⚡"
else "💡"
end

comment = <<~MD
  ## #{top_emoji} Evaluation Result — @#{student}

  > Ölçüm: #{RUNS} çalıştırmanın medyanı · GitHub Actions `ubuntu-latest`

  | Metrik | Baseline | Sonuç | İyileşme | Puan |
  |--------|----------|-------|----------|------|
  #{queries_row}
  #{time_row}

  ### Toplam: **#{score.total_score} / 90**

  | Bileşen | Hesap |
  |---------|-------|
  | Query azaltma (`×0.60`) | #{score.query_reduction_pct.round(1)}% × 0.60 = **#{query_pts}** |
  | Süre azaltma (`×0.30`) | #{score.time_reduction_pct.round(1)}% × 0.30 = **#{time_pts}** |
  | Stability bonus | CI'da uygulanmaz (local `rails dojo:run`'da aktif) |

  <details>
  <summary>Bireysel çalıştırmalar</summary>

  #{results.each_with_index.map { |r, i| "- Run #{i + 1}: #{r[:queries]} queries, #{r[:time].round(1)}ms" }.join("\n")}

  </details>
MD

File.write("tmp/eval_comment.md", comment)
puts "\nEvaluation complete. Results written to tmp/"
