#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/environment'
require 'benchmark'

puts "=== Rails Evaluation Lab ==="
puts "Target: UserDataFetcher#call"
puts "Checking environment..."

# 1. Anti-Cheat: Verify seeds haven't been tampered with to make it artificially fast
expected_users = 200
current_users = User.count

if current_users < expected_users
  puts "[ERROR] Cheat detected: Seed data tampered. Expected #{expected_users} users, got #{current_users}."
  exit 1
end

# 2. Correctness: Verify the result structure using RSpec
puts "Running correctness verification..."
spec_result = system("bundle exec rspec spec/services/user_data_fetcher_spec.rb --format doc")

unless spec_result
  puts "[ERROR] Correctness check failed. The service no longer returns the expected data structure."
  exit 1
end

# 3. Performance & Query Count: Benchmark the execution
puts "\n--- Benchmark ---"

# We use ActiveSupport::Notifications to count queries precisely
query_count = 0
subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  # Ignore schema and transaction queries
  unless event.payload[:name] == "SCHEMA" || [ "BEGIN", "COMMIT" ].include?(event.payload[:sql])
    query_count += 1
  end
end

puts "Measuring execution time and query count..."
time = Benchmark.realtime do
  UserDataFetcher.new.call
end

ActiveSupport::Notifications.unsubscribe(subscriber)

puts "\n=== Results ==="
puts "Execution Time: #{time.round(4)} seconds"
puts "Total SQL Queries: #{query_count}"

# Basic evaluation logic
if query_count > 100
  puts "\n[STATUS] POOR. The application is suffering from severe N+1 queries."
elsif query_count > 5
  puts "\n[STATUS] ACCEPTABLE. Some optimization done, but could be better."
else
  puts "\n[STATUS] EXCELLENT. Eager loading implemented perfectly!"
end
