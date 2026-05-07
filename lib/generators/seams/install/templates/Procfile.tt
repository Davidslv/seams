# Foreman / Kamal Procfile for a Seams-powered host.
#
# The worker process expects Solid Queue tables to already exist.
# If you haven't installed Solid Queue's migrations yet:
#
#   bin/rails solid_queue:install:migrations
#   bin/rails db:migrate
#
# Solid Queue Recurring is also needed if you ship the Notifications
# engine (it relies on the recurring sweeper). After installing,
# add the engine's recurring entries to config/recurring.yml — see
# the engine's README for the schedule.
web:    bundle exec rails server -p ${PORT:-3000} -b 0.0.0.0
worker: bundle exec rails solid_queue:start
