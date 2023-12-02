require 'java'
require 'glimmer-dsl-swt'
require_relative '../api/api'

java_import 'javax.swing.JFrame'

class Application
  include Glimmer

  def initialize
    @bot_loaded = false
    @bot_config_file = nil
    @bot_config = {}
    @bot_log = []
    @driver = nil
    @run_thread = nil
    @pause_interrupt = java.util.concurrent.atomic.AtomicBoolean.new
    @stop_interrupt = java.util.concurrent.atomic.AtomicBoolean.new
    @stop_safely_interrupt = java.util.concurrent.atomic.AtomicBoolean.new
    @shell = default_shell()

    #api_thread = Thread.new do
    #  api.run(host: '0.0.0.0', debug: false, use_reloader: false)
    #end
    ##api_thread.daemon = true
    #api_thread.abort_on_exception = true
    #api_thread.start

    #reset_run_thread
    show
  end

  def reset_run_thread
    @run_thread = Thread.new do
      initiate_driver
    end
    @run_thread.abort_on_exception = true
    #@run_thread.daemon = true
  end

  def initiate_driver
    begin
      log('starting bot...')
      @driver = libeve.driver.BotDriver.new(
        @bot_config_file,
        log_fn: method(:log),
        pause_interrupt: @pause_interrupt,
        pause_callback: method(:pause_callback),
        stop_interrupt: @stop_interrupt,
        stop_callback: method(:stop_callback),
        stop_safely_interrupt: @stop_safely_interrupt,
        stop_safely_callback: method(:stop_safely_callback)
      )
      @driver.bot.initialize
      @driver.start
    rescue Exception => e
      log("error: #{e}")
    ensure
      @run_thread.run
      @run_thread = nil
      @shell.get_button('run').enabled = true
      @shell.get_button('pause').enabled = false
      @shell.get_button('stop').enabled = false
      @shell.get_button('stop_safely').enabled = false
      reset_run_thread
      log('bot finished...')
    end
  end

  def log(message)
    @bot_log << message
    get_text('bot_log').text = @bot_log.join("\n")
  end

  def bot_is_running
    @run_thread&.alive? || false
  end

  def run
    unless bot_is_running
      @run_thread.run
      @shell.get_button('run').enabled = false
      @shell.get_button('pause').enabled = true
      @shell.get_button('stop').enabled = true
      @shell.get_button('stop_safely').enabled = true
    else
      log('bot is already running!')
    end
  end

  def pause
    @shell.get_button('pause').enabled = false
    @shell.get_button('stop').enabled = false
    @shell.get_button('stop_safely').enabled = false

    if @pause_interrupt.get
      log('resuming execution...')
      @pause_interrupt.set(false)
      @shell.get_button('pause').text = 'Pause'
    else
      log('pausing execution...')
      @pause_interrupt.set(true)
      @shell.get_button('pause').text = 'Play'
    end
  end

  def pause_callback
    @shell.get_button('pause').enabled = true

    unless @driver&.bot&.paused
      @shell.get_button('stop').enabled = true
      @shell.get_button('stop_safely').enabled = true
    else
      log('paused!')
    end
  end

  def stop
    @shell.get_button('pause').enabled = false
    @shell.get_button('stop').enabled = false
    @shell.get_button('stop_safely').enabled = false

    @stop_interrupt.set
  end

  def stop_callback
    @shell.get_button('run').enabled = true
    @shell.get_button('pause').enabled = false
    @shell.get_button('stop').enabled = false
    @shell.get_button('stop_safely').enabled = false
    @stop_interrupt.set(false)
    reset_run_thread
    log('stopped execution!')
  end

  def stop_safely
    @shell.get_button('pause').enabled = false
    @shell.get_button('stop').enabled = false
    @shell.get_button('stop_safely').enabled = false

    @stop_safely_interrupt.set
  end

  def stop_safely_callback
    @shell.get_button('run').enabled = true
    @shell.get_button('pause').enabled = false
    @shell.get_button('stop').enabled = false
    @shell.get_button('stop_safely').enabled = false
    @stop_safely_interrupt.set(false)
    reset_run_thread
    log('safely stopped execution!')
  end

  def load(values)
    bot_config_file = values['bot_config_file']
    return log("file does not exist: \"#{bot_config_file}\"") unless File.exist?(bot_config_file)

    begin
      bot_config = JSON.parse(File.read(bot_config_file))
    rescue JSON::ParserError
      return log("invalid bot config: \"#{bot_config_file}\"")
    end

    log("loaded bot file: \"#{bot_config_file}\"")
    @shell.get_text('currently_selected_bot').text = bot_config['uses'] || 'Unknown'
    @shell.get_button('run').enabled = true
    @bot_config_file = bot_config_file
    @bot_loaded = true
  end

  def default_shell
    @shell = shell {
      text 'EVE Online - Bot Application'
      minimum_size 1024, 768

      #row_layout(:vertical) { fill true; center true }

      ##on_close { dispose }
      #composite {
      #  grid_layout(1, false) { margin_width 10; margin_height 10 }
      #  file_list_column.each do |row_elements|
      #    composite {
      #      row_layout(:horizontal) { fill true; center true }
      #      row_elements.each do |element|
      #        if element.is_a?(Array)
      #          element.each do |inner_element|
      #            create_element(inner_element)
      #          end
      #        else
      #          create_element(element)
      #        end
      #      end
      #    }
      #  end
      #}
    }
  end

  def show
    @shell.open
    @shell.display #.event_loop
  end

  def create_element(element)
  #  case element[:type]
  #  when 'Button'
  #    button(element[:text]) {
  #      layout_data { 
  #        width 200
  #        height 100 
  #      }
  #      enabled element[:enabled]
  #      on_widget_selected { send(element[:key]) } if element[:key]
  #    }
  #  when 'Text'
  #    text(element[:text]) {
  #      layout_data { 
  #        width 200
  #        height 100 
  #      }
  #    }
  #  when 'MultiLine'
  #    multi_line {
  #      layout_data(:fill, :end, true, false)
  #      enabled element[:enabled]
  #    }
  #  when 'In'
  #    text {
  #      layout_data {
  #        width 200
  #        height 100
  #      }
  #      enabled element[:enabled]
  #      on_key_pressed { |event| load(event.text) if event.character == 13 } # Enter key
  #    }
  #  when 'FileBrowse'
  #    button {
  #      text 'Browse'
  #      layout_data(:fill, :center, true, true)
  #      on_widget_selected {
  #        file_dialog = Swt::Widgets::FileDialog.new(@shell.shell, Swt::SWT::OPEN)
  #        file = file_dialog.open
  #        @shell.get_text('bot_config_file').text = file if file
  #      }
  #    }
  #  end
  end

  private

  def file_list_column
    [
      [
        { type: 'Text', text: 'Bot: ' },
        { type: 'Text', text: '<No Bot Selected>', key: 'currently_selected_bot' }
      ],
      [
        { type: 'Button', text: 'Run', size: [5, 1], enabled: false, key: 'run' },
        { type: 'Button', text: 'Pause', size: [5, 1], enabled: false, key: 'pause' },
        { type: 'Button', text: 'Stop', size: [5, 1], enabled: false, key: 'stop' },
        { type: 'Button', text: 'Stop Safely', size: [10, 1], enabled: false, key: 'stop_safely' }
      ],
      { type: 'MultiLine', enabled: false, key: 'bot_log', size: [1000, 38] },
      [
        { type: 'In', size: [25, 1], enabled: false, key: 'bot_config_file' },
        { type: 'FileBrowse' }
      ]
    ]
  end
end

Application.new

