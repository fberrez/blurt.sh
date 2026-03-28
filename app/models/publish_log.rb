# frozen_string_literal: true

class PublishLog < ApplicationRecord
  validates :filename, presence: true
  validates :status, presence: true, inclusion: { in: %w[sent failed] }

  scope :sent, -> { where(status: "sent") }
  scope :failed, -> { where(status: "failed") }
  scope :for_platform, ->(platform) { where("platforms LIKE ?", "%#{platform}%") }
  scope :after_date, ->(date) { where("published_at >= ?", date) }
  scope :before_date, ->(date) { where("published_at <= ?", date) }

  def self.record!(post:, results:, status:, destination_path:)
    create!(
      filename: post.filename,
      title: post.title,
      status: status.to_s,
      platforms: post.platforms,
      results: results.select { |_, r| r[:url] }.transform_values { |r|
        { "url" => r[:url], "publishedAt" => r[:published_at]&.utc&.iso8601 }
      },
      publish_errors: results.select { |_, r| r[:error] }.transform_values { |r| r[:error] },
      destination_path: destination_path,
      published_at: Time.current
    )
  end
end
