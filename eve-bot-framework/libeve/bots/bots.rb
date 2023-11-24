require 'win32ole'
require_relative 'utils'
require_relative 'interface'

class Bot
  attr_accessor :pause_interrupt, :pause_callback, :stop_interrupt, :stop_callback, :stop_safely_interrupt, :stop_safely_callback

  def initialize(
    log_fn = method(:puts),
    pause_interrupt: nil,
    pause_callback: nil,
    stop_interrupt: nil,
    stop_callback: nil,
    stop_safely_interrupt: nil,
    stop_safely_callback: nil
  )
    @log_fn = log_fn
    @pause_interrupt = pause_interrupt
    @pause_callback = pause_callback
    @stop_interrupt = stop_interrupt
    @stop_callback = stop_callback
    @stop_safely_interrupt = stop_safely_interrupt
    @stop_safely_callback = stop_safely_callback
    @stopping_safely = false
    @paused = false
    @tree = nil
  end

  def initialize
    say('Initializing')
    say("detected screen size: #{Utils.get_screensize}", narrate: false)
    @tree = UITree.new
    say('Ready')
  end

  def check_pause_interrupt
    while @pause_interrupt && @pause_interrupt.set?
      if !@paused
        @paused = true
        @pause_callback&.call
      end
      sleep(0.25)
    end
    if @paused
      @paused = false
      @pause_callback&.call
    end
  end

  def stop
    @tree = nil
  end

  def check_stop_interrupt
    if @stop_interrupt && @stop_interrupt.set?
      @stop_callback&.call
      stop
      exit(1)
    end
  end

  def check_stop_safely_interrupt
    if @stop_safely_interrupt && @stop_safely_interrupt.set?
      if !@stopping_safely && @stop_safely_callback&.call
        log_fn('stop safely interrupt triggered')
        @stopping_safely = true
        ensure_within_station
        @stop_safely_callback&.call
        exit(1)
      end
    end
  end

  def check_interrupts
    check_pause_interrupt
    check_stop_interrupt
    check_stop_safely_interrupt
  end

  def speak(text)
    Thread.new { WIN32OLE.new('SAPI.SpVoice').Speak(text) }
  end

  def say(text, narrate: true)
    check_interrupts
    @log_fn.call(text)
    speak(text) if narrate
  end

  def focus(prefix = 'eve - ')
    check_interrupts
    top_windows = []
    win32gui.EnumWindows(Utils.method(:window_enumeration_handler), top_windows)
    top_windows.each do |i|
      if i[1].downcase.include?(prefix)
        win32gui.ShowWindow(i[0], 5)
        win32gui.SetForegroundWindow(i[0])
        break
      end
    end
    sleep(1)
  end

  def move_cursor_to_node(node)
    check_interrupts
    x = (node.x * @tree.width_ratio + node.attrs['_displayWidth'] / 2).to_i
    y = (node.y * @tree.height_ratio + node.attrs['_displayHeight'] / 2).to_i
    puts "setting cursor to #{x}, #{y}"
    win32api.SetCursorPos(x, y)
    sleep(1)
    [x, y]
  end

  def click_node(node, right_click: false, times: 1, expect: [], expect_args: {})
    check_interrupts
    x, y = move_cursor_to_node(node)
    down_event = right_click ? win32con.MOUSEEVENTF_RIGHTDOWN : win32con.MOUSEEVENTF_LEFTDOWN
    up_event = right_click ? win32con.MOUSEEVENTF_RIGHTUP : win32con.MOUSEEVENTF_LEFTUP
    times.times do
      win32api.mouse_event(down_event, x, y, 0, 0)
      sleep(1)
      win32api.mouse_event(up_event, x, y, 0, 0)
      sleep(1)
      puts 'clicked'
    end
    expect.each do |expectation|
      unless wait_for(expectation, until: 10, **expect_args)
        win32api.mouse_event(down_event, x, y, 0, 0)
        sleep(1)
        win32api.mouse_event(up_event, x, y, 0, 0)
        sleep(1)
        while !(tmp_node = @tree.find_node(address: node.address))
          sleep(2)
        end
        node = tmp_node
        return click_node(node: node, right_click: right_click, times: times, expect: expect, expect_args: expect_args)
      end
    end
    sleep(1)
    [x, y]
  end

  def drag_node_to_node(src_node, dest_node)
    check_interrupts
    x, y = move_cursor_to_node(src_node)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTDOWN, x, y, 0, 0)
    sleep(1)
    x, y = move_cursor_to_node(dest_node)
    win32api.mouse_event(win32con.MOUSEEVENTF_LEFTUP, x, y, 0, 0)
    sleep(1)
    puts 'dragged'
    [x, y]
  end

  def wait_for(query: {}, address: nil, type: nil, select_many: false, contains: false, timeout: 0)
    check_interrupts
    puts "waiting for query=#{query}, address=#{address}, type=#{type}, select_many=#{select_many}, contains=#{contains}"
    started = Time.now.to_i
    node = nil
    until (node = @tree.find_node(query, address, type, select_many, contains)) do
      break if timeout && Time.now.to_i - started >= timeout
    end
    sleep(1)
    node
  end


  def undock
    undock_btn = wait_for({_setText: 'Undock'}, type: 'EveLabelMedium', until: 5)
    say('undocking')
    click_node(undock_btn)
    wait_for_overview
  end

  def wait_for_overview
    wait_for({_setText: 'Overview'}, type: 'Label', contains: true)
  end

  def wait_until_warp_finished
    wait_for({_setText: 'Warp Drive Active'})
    say('warp drive active')
    while @tree.find_node({_setText: 'Warp Drive Active'})
      sleep(2)
    end
    say('warp drive disengaged')
    sleep(5)
  end

  def wait_until_jump_finished
    wait_for({_setText: 'Jumping'})
    say('jumping')
    while @tree.find_node({_setText: 'Jumping'})
      sleep(2)
    end
    sleep(2)
  end

  def recall_drones
    say('Recalling drones')

    drones_in_space = wait_for(
      { '_setText': 'Drones in Space (' },
      type: 'EveLabelMedium',
      contains: true,
      until: 5
    )

    click_node(drones_in_space, right_click: true)
    recall_btn = wait_for(
      { '_setText': 'Recall Drones' },
      type: 'EveLabelMedium',
      contains: true
    )

    click_node(recall_btn)
    sleep(5)


  def ensure_within_station
    undock_btn = wait_for(
      { '_setText': 'Undock' },
      type: 'LabelThemeColored',
      until: 5
    )
    return if undock_btn
  
    recall_drones
  
    loop do
      wait_for_overview
      say('Finding station')
      sleep(3)
  
      station = wait_for(
        { '_text': @station },
        type: 'OverviewLabel',
        until: 10
      )
  
      unless station
        warpto_tab = wait_for(
          { '_setText': 'WarpTo' },
          type: 'LabelThemeColored'
        )
  
        click_node(
          warpto_tab,
          times: 2,
          expect: [{ '_text': @station }],
          expect_args: { 'type': 'OverviewLabel' }
        )
  
        station = wait_for({ '_text': @station }, type: 'OverviewLabel')
      end
  
      click_node(station)
  
      dock_btn = wait_for(
        { '_name': 'selectedItemDock' },
        type: 'SelectedItemButton'
      )
  
      click_node(dock_btn)
  
      wait_until_warp_finished if wait_for({ '_setText': 'Establishing Warp Vector' }, until: 5)
  
      break
    end
  
    wait_for({ '_setText': 'Undock' }, type: 'LabelThemeColored')
    sleep(5)
  end
end
