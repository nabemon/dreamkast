require 'slack/incoming/webhooks'

namespace :util do
  desc "post_number_of_registrants_to_slack"
  task post_number_of_registrants_to_slack: :environment do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    Rails.logger.level = Logger::DEBUG

    url = ENV['SLACK_WEBHOOK_URL']
    abbr = ENV['CONFERENCE_ABBR']
    slack = Slack::Incoming::Webhooks.new(url)
    slack.username = "#{conference.abbr.upcase} 参加者速報"
    body = ''

    ActiveRecord::Base.transaction do
      begin
        conference = Conference.find_by(abbr: abbr)
        conference.profiles.size
        stats = StatsOfRegistrant.new(conference_id: conference.id, number_of_registrants: conference.profiles.size)
        stats.save!

        yesterday_stats = StatsOfRegistrant.where('created_at < ?', 1.days.ago).first

        body = <<-EOS
#{stats.created_at.strftime("%Y-%m-%d %H:%M")} 時点の参加者登録数は #{stats.number_of_registrants} 人です！
前日より #{stats.number_of_registrants - yesterday_stats.number_of_registrants} 人増えました！
        EOS
      rescue => e
        puts e
      end
    end

    slack.post body unless body.empty?
  end
end
