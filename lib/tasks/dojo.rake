# frozen_string_literal: true

namespace :dojo do
  desc "Run evaluation with strategy note. Usage: rails dojo:run -- 'your strategy note here'"
  task run: :environment do
    # Extract strategy note from command line arguments after --
    strategy_note = ARGV.drop_while { |a| a != "--" }.drop(1).join(" ")

    if strategy_note.blank?
      puts "❌ Strateji notu zorunlu!"
      puts ""
      puts "Kullanım:"
      puts '  rails dojo:run -- "includes ile N+1 çözdüm"'
      puts ""
      puts "Not: Minimum 20 karakter. Ne değiştirdiğinizi ve NEDEN değiştirdiğinizi yazın."
      exit 1
    end

    user = User.first
    challenge = Challenge.find_by!(slug: "n_plus_one_dashboard")

    puts "=" * 60
    puts "🥋 ENGINEERING DOJO — Evaluation Run"
    puts "=" * 60
    puts ""
    puts "Credits: #{user.credits} (cost: #{challenge.credit_cost})"
    puts "Strategy: #{strategy_note}"
    puts ""
    puts "Running scorer..."
    puts ""

    result = EvaluationEngine::ExecuteRun.call(
      user: user,
      challenge: challenge,
      strategy_note: strategy_note
    )

    if result.failure?
      puts "❌ #{result.error}"
      exit 1
    end

    log = result.run_log
    prev = RunLog.where(user: user, challenge: challenge)
                 .where.not(id: log.id)
                 .order(iteration_number: :desc)
                 .first

    puts "✅ Iteration ##{log.iteration_number} Complete"
    puts "-" * 40
    puts "Queries:    #{log.queries_count} (baseline: #{challenge.baseline_queries})"
    puts "Time:       #{log.execution_time_ms}ms (baseline: #{challenge.baseline_time_ms}ms)"
    puts "Score:      #{log.total_score} / 100"
    puts ""

    if prev
      delta = log.total_score - prev.total_score
      arrow = delta.positive? ? "📈" : delta.negative? ? "📉" : "➡️"
      puts "#{arrow} Previous: #{prev.total_score} → Current: #{log.total_score} (#{delta >= 0 ? '+' : ''}#{delta.round(2)})"
      puts ""
      if delta.negative?
        puts "⚠️  Score düştü! Revert etmeyi düşün:"
        puts "    git checkout -- app/services/user_data_fetcher.rb"
      end
    end

    puts ""
    puts "Credits remaining: #{user.reload.credits}"
    remaining_runs = user.credits / challenge.credit_cost
    puts "Runs left: #{remaining_runs}"

    if remaining_runs <= 3
      puts ""
      puts "⚠️  Son #{remaining_runs} hakkınız! Her çalıştırmayı iyi düşünün."
    end

    puts ""
    puts "=" * 60

    # Prevent rake from interpreting strategy note args as task names
    ARGV.drop_while { |a| a != "--" }.drop(1).each { |a| task a.to_sym do; end }
  end

  desc "Show run history and remaining credits"
  task status: :environment do
    user = User.first
    challenge = Challenge.find_by!(slug: "n_plus_one_dashboard")
    logs = RunLog.where(user: user, challenge: challenge).order(:iteration_number)

    puts "=" * 60
    puts "🥋 ENGINEERING DOJO — Status"
    puts "=" * 60
    puts ""
    puts "Credits: #{user.credits} / 100 (#{user.credits / challenge.credit_cost} runs left)"
    puts ""

    if logs.empty?
      puts "Henüz çalıştırma yok. Başla:"
      puts '  rails dojo:run -- "strateji notunuz"'
    else
      puts "#{'#'.ljust(4)} #{'Queries'.ljust(10)} #{'Time'.ljust(12)} #{'Score'.ljust(8)} Strategy"
      puts "-" * 60
      logs.each do |log|
        puts "#{log.iteration_number.to_s.ljust(4)} #{log.queries_count.to_s.ljust(10)} #{(log.execution_time_ms.to_s + 'ms').ljust(12)} #{log.total_score.to_s.ljust(8)} #{log.strategy_note.truncate(30)}"
      end
    end

    puts ""
    puts "=" * 60
  end
end
