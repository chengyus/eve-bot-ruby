require 'json'
require 'twilio-ruby'
require_relative 'bots/autopilot'
require_relative 'bots/mining'

class BotDriver
  @@registered_bots = { 'AutoPilotBot' => AutoPilotBot, 'MiningBot' => MiningBot }

  def initialize(
    driver_filename,
    log_fn = method(:puts),
    pause_interrupt: nil,
    pause_callback: nil,
    stop_interrupt: nil,
    stop_callback: nil,
    stop_safely_interrupt: nil,
    stop_safely_callback: nil
  )
    @driver_filename = driver_filename
    @driver = JSON.parse(File.read(@driver_filename))
    @muted = !@driver.fetch('with_narration', false)
    @bot_name = @driver['uses']
    @start_from = @driver['start_from']
    @focus_enabled = @driver.fetch('focus', false)
    @loop = @driver.fetch('loop', false)
    @sms_number = @driver['sms_number']
    @scanners = @driver.fetch('scanners', [])
    @args = @driver.fetch('args', {})
    @started = false
    @log_fn = log_fn
    @pause_interrupt = pause_interrupt
    @pause_callback = pause_callback
    @stop_interrupt = stop_interrupt
    @stop_callback = stop_callback
    @stop_safely_interrupt = stop_safely_interrupt
    @stop_safely_callback = stop_safely_callback

    raise "`uses` key must be present in #{@driver_filename}" unless @bot_name
    raise "`#{@bot_name}` is not a registered bot" unless @@registered_bots.key?(@bot_name)

    @bot = @@registered_bots[@bot_name].new(
      log_fn: @log_fn,
      pause_interrupt: @pause_interrupt,
      pause_callback: @pause_callback,
      stop_interrupt: @stop_interrupt,
      stop_callback: @stop_callback,
      stop_safely_interrupt: @stop_safely_interrupt,
      stop_safely_callback: @stop_safely_callback,
      **@args
    )

    start_scanners
  end

  def start_scanners
    # Implement scanner logic if needed
  end

  def start
    return @log_fn.call('bot is not initialized!') unless @bot.tree

    begin
      loop do
        @driver.fetch('steps', []).each do |step|
          next unless !@started && @start_from && @start_from != step

          @bot.focus if @focus_enabled
          @started = true
          fn = @bot.method(step)
          raise "`#{step}` is not a registered action in bot `#{@bot_name}`" unless fn && fn.respond_to?(:call)

          @log_fn.call("== running step: #{step}")
          fn.call
        end
        break unless @loop
      end
    rescue StandardError => e
      puts e.message
      puts e.backtrace.join("\n")
      if twilio_configured && @sms_number
        client = Twilio::REST::Client.new account_sid, auth_token
        message = client.messages.create(
          body: 'Mining Bot failed.',
          from: '+13855955197',
          to: @sms_number
        )
      end
      loop do
        @driver.bot.say('Error, attention needed')
        sleep(5)
      end
    ensure
      @bot.tree.cleanup
    end
  end

  private

  def twilio_configured
    !!account_sid && !!auth_token
  end

  def account_sid
    ENV['TWILIO_ACCOUNT_SID']
  end

  def auth_token
    ENV['TWILIO_AUTH_TOKEN']
  end
end

