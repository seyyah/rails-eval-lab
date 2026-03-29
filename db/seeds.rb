# frozen_string_literal: true

require "faker"

# Fixed seed for deterministic data generation.
# Every student gets the same dataset → scores are comparable.
Faker::Config.random = Random.new(42)
srand(42)

USER_COUNT = 200
ACTIVE_RATIO = 0.5 # exactly 100 active users

puts "Generating #{USER_COUNT} users with profiles, posts, and comments..."

USER_COUNT.times do |i|
  is_active = i < (USER_COUNT * ACTIVE_RATIO) # first 100 active, rest inactive

  user = User.create!(
    name: Faker::Name.name,
    email: "user#{i + 1}@dojo.test",
    active: is_active
  )

  Profile.create!(
    user: user,
    bio: Faker::Lorem.paragraph,
    avatar_url: Faker::Avatar.image
  )

  rand(5..15).times do
    post = user.posts.create!(
      title: Faker::Lorem.sentence,
      body: Faker::Lorem.paragraphs(number: 2).join("\n\n"),
      published: [true, false].sample
    )

    rand(1..3).times do
      post.comments.create!(
        author_name: Faker::Name.name,
        body: Faker::Lorem.sentence
      )
    end
  end
end

puts "Seeded #{User.count} users, #{Profile.count} profiles, #{Post.count} posts, #{Comment.count} comments"
puts "Active users: #{User.where(active: true).count}"

# --- Challenge baseline ---
# After seeding, run Scorer once to capture the actual baseline.
challenge = Challenge.find_or_create_by!(slug: "n_plus_one_dashboard") do |c|
  c.title = "Dashboard N+1 Katliamı"
  c.description = "Kullanıcı dashboard'u binlerce SQL sorgusu çalıştırıyor. Düzelt."
  c.baseline_queries = 1  # placeholder, updated below
  c.baseline_time_ms = 1  # placeholder, updated below
  c.credit_cost = 5
end

puts "Measuring baseline..."
baseline = Scorer.run(challenge)
challenge.update!(
  baseline_queries: baseline[:queries],
  baseline_time_ms: baseline[:time]
)
puts "Baseline measured: #{baseline[:queries]} queries, #{baseline[:time].round(2)}ms"
puts "Challenge '#{challenge.slug}' ready."
