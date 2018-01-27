# Slack bot for ProfitTrailer

## Setup
1. Clone this repo and run `bundle install`
2. Setup a Slack bot for your workspace and grab it's `API_TOKEN`

## Run

```
SLACK_API_TOKEN=my-token-here \
SLACK_RUBY_BOT_ALIASES=pt \
PROFIT_TRAILER_URL=http://localhost:8081 \
PROFIT_TRAILER_PASSWORD=password \
bundle exec ruby profit_trailer_bot.rb
```
