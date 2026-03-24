# frozen_string_literal: true

Rails.application.config.after_initialize do
  configured = BlurtConfig.configured_platforms
  if configured.any?
    Rails.logger.info "[blurt] Configured platforms: #{configured.join(', ')}"
  else
    Rails.logger.warn "[blurt] No platforms configured. Set env vars in .env"
  end

  Rails.logger.info "[blurt] Poll interval: #{BlurtConfig.poll_interval}ms"
end
