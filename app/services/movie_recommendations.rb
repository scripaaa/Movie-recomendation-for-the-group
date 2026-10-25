# Ranks a bounded TMDB candidate pool; this is a heuristic, not a probability.
class MovieRecommendations
  GENRES = { "comedy" => 35, "drama" => 18, "science_fiction" => 878,
             "thriller" => 53, "adventure" => 12, "animation" => 16 }.freeze
  Result = Data.define(:movie, :score, :reason)

  def initialize(user: nil, users: nil, client: Tmdb::MovieSearch.new)
    @users = Array(users || user).uniq(&:id)
    @group = users.present?
    @client = client
  end

  def call(genre: nil, duration: nil, exclude_watched: true, limit: 12, genre_adjustments: {})
    genre_id = GENRES[genre]
    duration = duration.to_i if %w[90 120 180].include?(duration.to_s)
    duration = nil unless [ 90, 120, 180 ].include?(duration)
    ratings = Rating.where(user_id: @users.map(&:id)).includes(:movie).order(:id).to_a
    movies = ratings.map(&:movie).index_by(&:id)
    # Backfill movies rated before genre storage was introduced, without unbounded API calls.
    movies.values.select { |movie| movie.genre_ids.nil? }.first(5).each do |movie|
      details = @client.details(movie.tmdb_id.to_s)
      movie.update!(genre_ids: details.fetch("genres", []).map { |item| item.fetch("id") })
    end
    weights = genre_weights(ratings, movies)
    if @group
      genre_adjustments.each do |id, adjustment|
        weights[id.to_i] = weights.fetch(id.to_i, 0.0) + adjustment
      end
    end
    preferred = weights.select { |_id, weight| weight.positive? }.sort_by { |id, weight| [ -weight, id ] }.first(3).map(&:first)
    filters = genre_id ? [ genre_id ] : []
    candidates = (1..2).flat_map { |page| @client.discover(genre_ids: filters, duration: duration, page: page) }
    if genre_id.nil? && preferred.any?
      candidates += @client.discover(genre_ids: preferred, duration: duration, page: 1)
    end
    watched = ratings.map { |rating| rating.movie.tmdb_id }
    candidates.uniq { |movie| movie.fetch("id") }.filter_map do |movie|
      next if exclude_watched && watched.include?(movie.fetch("id"))
      ids = movie.fetch("genre_ids", [])
      next if genre_id && !ids.include?(genre_id)

      affinity = ids.empty? ? 0.0 : ids.sum { |id| weights.fetch(id, 0.0) } / ids.size
      # Shrink public scores toward 5 for titles with few votes.
      votes = [ movie["vote_count"].to_i, 0 ].max
      quality = (movie["vote_average"].to_f * votes + 5.0 * 100) / (votes + 100)
      matched = ids.any? { |id| weights.fetch(id, 0).positive? }
      reason = if @group
        matched ? "Жанры совпадают с предпочтениями участников комнаты." : "Популярный фильм с учётом пожеланий вашей компании."
      else
        matched ? "Жанры совпадают с фильмами, которые вы высоко оценили." : "Популярный фильм с учётом ваших пожеланий."
      end
      Result.new(movie: movie, score: affinity * 2 + quality / 10, reason: reason)
    end.sort_by { |result| [ -result.score, -result.movie["vote_count"].to_i, result.movie.fetch("id") ] }.first(limit)
  end

  private

  def genre_weights(ratings, movies)
    user_weights = ratings.group_by(&:user_id).values.map do |user_ratings|
      totals = Hash.new(0.0)
      counts = Hash.new(0)
      user_ratings.each do |rating|
        Array(movies.fetch(rating.movie_id).genre_ids).each do |id|
          totals[id] += (rating.score - 5.5) / 4.5
          counts[id] += 1
        end
      end
      totals.to_h { |id, total| [ id, total / counts[id] ] }
    end
    # Average each person's preferences first, so prolific raters do not dominate the room.
    user_weights.flat_map(&:keys).uniq.to_h do |id|
      [ id, user_weights.sum { |weights| weights.fetch(id, 0.0) } / @users.size ]
    end
  end
end
