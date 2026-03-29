# Program

You are an autonomous optimization agent working inside the Engineering Dojo —
an evaluation-driven system with a hard credit constraint.

## Objective

Reduce the SQL query count and execution time of `UserDataFetcher` as measured
by the deterministic Scorer. Every improvement must be proven by measurement,
not assumed from code reading.

## Architecture

```
app/services/user_data_fetcher.rb   ← THE ONLY FILE YOU MODIFY
app/services/scorer.rb              ← runs UserDataFetcher, counts queries, measures time
app/services/evaluation_engine/     ← orchestrates credit deduction + scoring + logging
db/seeds.rb                         ← ~200 users, ~1000 posts, ~3000 comments (DO NOT TOUCH)
```

## The Constraint: 20 Attempts Maximum

You have **100 credits**. Each evaluation costs **5 credits**. That gives you
exactly **20 runs** — then you are permanently blocked. There are no refills.

This is not a suggestion. This is a hard database constraint. Plan accordingly.

### What This Means

- Do NOT run evaluations to "see what happens." Every run must test a specific hypothesis.
- Do NOT attempt to solve everything in one step. But also do not waste runs on trivial changes.
- Before each run, write your hypothesis in `claude.md`. After each run, record the result.
- If a change makes things worse: revert immediately via `git checkout -- app/services/user_data_fetcher.rb`

## Scoring Formula (0–100 scale)

Your score is calculated from the baseline metrics stored in the challenges table:

| Component        | Weight | Formula                                                       |
|------------------|--------|---------------------------------------------------------------|
| Query Reduction  | 60%    | ((baseline_queries − your_queries) / baseline_queries) × 100 |
| Time Reduction   | 30%    | ((baseline_time − your_time) / baseline_time) × 100          |
| Stability Bonus  | 10%    | Consistency with your previous run (0 on first run)           |

**Maximize query reduction first.** It is worth twice as much as time reduction.

## Rules (Immutable)

1. **Only modify:** `app/services/user_data_fetcher.rb`
2. **Never modify:** models, schema, migrations, seeds, scorer, evaluation engine
3. **Output contract:** `UserDataFetcher.new.call` must return the identical data structure.
   Same keys, same values, same nesting. If the output shape changes, the run is invalid.
4. **No caching tricks:** The optimization must be in how you query, not in memoization or Rails.cache.

## Known Bottleneck (Starting Point)

The current `UserDataFetcher` has **3 layers of N+1 queries**:

```
User.where(active: true)             →  1 query
  user.profile       (per user)      →  ~100 queries
  user.posts         (per user)      →  ~100 queries
    post.comments    (per post)      →  ~1000 queries
                                       ≈ 1200 total
```

This is your starting landscape. The obvious fix is eager loading, but HOW you
eager load (includes vs preload vs eager_load) and WHAT you eager load
(all associations vs selective) will produce different query counts and times.
Think before you act.

## Experiment Protocol

For each iteration:

1. Write hypothesis in `claude.md` BEFORE making any code change
2. Make exactly ONE conceptual change to `user_data_fetcher.rb`
3. Run evaluation: `rails runner "puts Scorer.run(Challenge.find_by(slug: 'n_plus_one_dashboard')).inspect"`
4. Record the result in `claude.md`
5. If improved → `git add -A && git commit -m "iteration N: <what you did>"`
6. If worse or equal → `git checkout -- app/services/user_data_fetcher.rb`

## Thinking Framework

Before spending a credit, ask yourself:
- What specific SQL queries will this change eliminate?
- Can I predict the approximate new query count BEFORE running?
- Is this worth 5 credits, or can I combine it with another change?