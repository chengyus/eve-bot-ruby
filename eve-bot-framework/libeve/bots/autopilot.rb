class AutoPilotBot < Bot
  def initialize(
      log_fn: method(:puts),
      pause_interrupt: nil,
      pause_callback: nil,
      stop_interrupt: nil,
      stop_callback: nil,
      stop_safely_interrupt: nil,
      stop_safely_callback: nil
  )
    super(
      log_fn: log_fn,
      pause_interrupt: pause_interrupt,
      pause_callback: pause_callback,
      stop_interrupt: stop_interrupt,
      stop_callback: stop_callback,
      stop_safely_interrupt: stop_safely_interrupt,
      stop_safely_callback: stop_safely_callback
    )
  end

  def go
    while true
      route = wait_for({_name: 'markersParent'}, type: 'Container', until: 15)

      break unless route

      waypoint_id = route.children.first

      def jump
        jump_btn = wait_for({_setText: 'Jump through stargate'}, type: 'EveLabelMedium', until: 5)

        return unless jump_btn

        say('jumping')
        click_node(jump_btn)
        wait_for({_setText: 'Establishing Warp Vector'}, until: 5)
        wait_until_warp_finished
        sleep(10)
      end

      def dock
        dock_btn = wait_for({_setText: 'Dock'}, type: 'EveLabelMedium', until: 5)

        return -1 unless dock_btn

        say('docking')
        click_node(dock_btn)
        wait_for({_setText: 'Establishing Warp Vector'}, until: 5)
        wait_until_warp_finished
        wait_for_overview
      end

      def jump_or_dock
        waypoint = tree.nodes[waypoint_id]
        click_node(waypoint, right_click: true)

        if route.children.length == 1
          return jump_or_dock if dock == -1

          jump
          return
        else
          jump
          return
        end
      end

      jump_or_dock
      break
    end
  end
end

