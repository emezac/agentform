# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

# Check for trial expirations daily at 9 AM
every 1.day, at: '9:00 am' do
  runner "TrialExpirationCheckJob.perform_later"
end

# Check for high response volumes every hour
every 1.hour do
  runner "ResponseVolumeCheckJob.perform_later"
end

# Clean up old notifications (older than 90 days) weekly
every 1.week, at: '2:00 am' do
  runner "AdminNotification.where('created_at < ?', 90.days.ago).delete_all"
end