# api.rb
require 'sinatra/base'
require 'json'

class BotView < Sinatra::Base

  def self.app=(app)
    @@app = app
  end

  get '/api/v1/healthcheck' do
    "200"
  end

  post '/api/v1/pause' do
    @@app.pause
    { status: 'ok', paused: !@@app.driver.bot.paused }.to_json
  end

  post '/api/v1/stop' do
    @@app.stop
    { status: 'ok' }.to_json
  end

  post '/api/v1/stop_safely' do
    @@app.stop_safely
    { status: 'ok' }.to_json
  end

end

#run BotView.start!

