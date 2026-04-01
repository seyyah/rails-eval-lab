# frozen_string_literal: true

class UserDataFetcher
  def call
    # DEĞİŞİKLİK BURADA: includes ile tüm ilişkili verileri tek seferde çekiyoruz.
    users = User.includes(:profile, posts: :comments).where(active: true)

    users.map do |user|
      serialize_user(user)
    end
  end

  private

  def serialize_user(user)
    {
      name: user.name,
      email: user.email,
      profile: serialize_profile(user.profile),
      posts: user.posts.map { |post| serialize_post(post) }
    }
  end

  def serialize_profile(profile)
    return nil unless profile

    {
      bio: profile.bio,
      avatar_url: profile.avatar_url
    }
  end

  def serialize_post(post)
    {
      title: post.title,
      body: post.body,
      published: post.published,
      comments: post.comments.map { |comment| serialize_comment(comment) }
    }
  end

  def serialize_comment(comment)
    {
      author_name: comment.author_name,
      body: comment.body
    }
  end
end