#!/usr/bin/env ruby
# frozen_string_literal: true

# Leaderboard Updater
#
# Reads tmp/eval_result.json, fetches current LEADERBOARD.md from the
# leaderboard branch (via git show), merges the new entry, re-ranks,
# and writes tmp/LEADERBOARD.md for the workflow to push.

require "json"
require "date"
require "fileutils"

FileUtils.mkdir_p("tmp")

result = JSON.parse(File.read("tmp/eval_result.json"))

# --- Load existing entries from leaderboard branch ---
existing_md = `git show origin/leaderboard:LEADERBOARD.md 2>/dev/null`
entries = []

if existing_md && !existing_md.empty?
  existing_md.each_line do |line|
    # Match data rows: | rank | @student | queries | time | score | #pr | date |
    next unless line.match?(/^\|\s*\d+\s*\|/)
    parts = line.split("|").map(&:strip).reject(&:empty?)
    next unless parts.length >= 7

    entries << {
      student:  parts[1].delete_prefix("@"),
      queries:  parts[2].to_i,
      time_ms:  parts[3].to_f,
      score:    parts[4].gsub(/[^0-9.]/, "").to_f,
      pr:       parts[5].delete_prefix("#").to_i,
      date:     parts[6]
    }
  end
end

# --- Upsert: keep only the student's best score ---
student = result["student"]
new_entry = {
  student:  student,
  queries:  result["queries"],
  time_ms:  result["time_ms"],
  score:    result["total_score"],
  pr:       result["pr_number"],
  date:     Date.today.to_s
}

existing = entries.find { |e| e[:student] == student }
if existing.nil? || new_entry[:score] >= existing[:score]
  entries.reject! { |e| e[:student] == student }
  entries << new_entry
  puts "#{student}: new best score #{new_entry[:score]}"
else
  puts "#{student}: previous score #{existing[:score]} is better than #{new_entry[:score]}, keeping old"
end

# --- Rank: score desc, then queries asc ---
entries.sort_by! { |e| [ -e[:score], e[:queries] ] }

medal = %w[🥇 🥈 🥉]
rows = entries.each_with_index.map do |e, i|
  rank = medal[i] || (i + 1).to_s
  "| #{rank} | @#{e[:student]} | #{e[:queries]} | #{e[:time_ms]} | **#{e[:score]}** | ##{e[:pr]} | #{e[:date]} |"
end

# --- Write LEADERBOARD.md ---
content = <<~MD
  # Leaderboard — Dashboard N+1 Katliamı

  > Son güncelleme: #{Time.now.utc.strftime("%Y-%m-%d %H:%M UTC")}
  > Ölçüm: GitHub Actions `ubuntu-latest` · 3 çalıştırmanın medyanı
  > Her öğrencinin **en iyi** skoru gösterilir

  | Rank | Öğrenci | Queries | Süre (ms) | Skor (/90) | PR | Tarih |
  |------|---------|---------|-----------|------------|-----|-------|
  #{rows.join("\n")}

  ---

  ## Puanlama

  | Bileşen | Ağırlık | Açıklama |
  |---------|---------|----------|
  | Query azaltma | %60 | Deterministik — her makinede aynı |
  | Süre azaltma | %30 | CI runner'da standardize (ubuntu-latest) |
  | Stability bonus | — | CI'da uygulanmaz (`rails dojo:run`'da aktif) |

  Baseline öğrencinin **kendi kodu** ile ölçülmez — ana repo'nun orijinal
  N+1 implementasyonu ile ölçülür. Tüm öğrenciler aynı baseline üzerinden yarışır.
MD

File.write("tmp/LEADERBOARD.md", content)
puts "Leaderboard written: #{entries.length} entries"
puts entries.map { |e| "  #{e[:student]}: #{e[:score]}" }.join("\n")
