require 'securerandom'
require 'json'
require 'ostruct'
require 'timeout'

class MiningBot
  def initialize(
    log_fn: method(:puts),
    pause_interrupt: nil,
    pause_callback: nil,
    stop_interrupt: nil,
    stop_callback: nil,
    stop_safely_interrupt: nil,
    stop_safely_callback: nil,
    deploy_drones_while_mining: false,
    station: nil,
    number_of_miners: 1,
    shields: nil,
    asteroids_of_interest: [],
    fleet_commander: nil
  )
    @log_fn = log_fn
    @pause_interrupt = pause_interrupt
    @pause_callback = pause_callback
    @stop_interrupt = stop_interrupt
    @stop_callback = stop_callback
    @stop_safely_interrupt = stop_safely_interrupt
    @stop_safely_callback = stop_safely_callback

    @visited_asteroid_belts = []
    @deploy_drones_while_mining = deploy_drones_while_mining
    @station = station
    @number_of_miners = number_of_miners
    @shields = shields
    @asteroids_of_interest = asteroids_of_interest
    @matched_asteroids = []
    @fleet_commander = fleet_commander
    @trip_id = ''
    @current_asteroid = nil
    @asteroids_mined = 0
    @shields_enabled = false
  end

  def new_trip
    @trip_id = SecureRandom.hex(16)
  end

  def undock
    super
    @visited_asteroid_belts = []
    @shields_enabled = false
    new_trip
  end

  def ensure_fleet_hangar_open
    fleet_hangar = wait_for(
      { '_setText': ' (Fleet Hangar)' },
      type: 'Label',
      contains: true,
      until: 5
    )

    if fleet_hangar
      say('fleet hangar open')
      click_node(fleet_hangar, times: 2)
      return
    end

    loop do
      say('opening fleet hangar')

      wait_for_overview
      sleep(5)

      fleet_tab = wait_for(
        { '_setText': 'Fleet' },
        type: 'LabelThemeColored'
      )

      click_node(
        fleet_tab,
        times: 2,
        expect: [{ '_text': @fleet_commander }],
        expect_args: { 'type': 'OverviewLabel' }
      )

      click_node(
        wait_for(
          { '_text': @fleet_commander },
          type: 'OverviewLabel'
        ),
        right_click: true
      )

      open_fleet_hangar_btn = wait_for(
        { '_setText': 'Open Fleet Hangar' },
        type: 'EveLabelMedium'
      )

      click_node(open_fleet_hangar_btn)

      fleet_hangar = wait_for(
        { '_setText': ' (Fleet Hangar)' },
        type: 'Label',
        contains: true,
        until: 5
      )

      next unless fleet_hangar

      click_node(fleet_hangar, times: 2)
      break
    end
  end

  def compress
    loop do
      ensure_fleet_hangar_open

      fleet_info = wait_for(
        { '_setText': '<br>Distance:' },
        type: 'EveLabelSmall',
        contains: true
      )

      name, distance_str, _ = fleet_info.attrs['_setText'].split('<br>')

      _, dist_str, unit = distance_str.strip.split(' ')

      dist = dist_str.delete(',').to_i

      dist /= 1000 if unit == 'm'

      if dist > 2.5
        approach_btn = wait_for(
          { '_name': 'selectedItemApproach' },
          type: 'SelectedItemButton'
        )

        click_node(approach_btn)
        sleep(5)
        next
      end

      ensure_mining_hold_is_open

      items = wait_for(
        { '_name': 'itemNameLabel' },
        type: 'Label',
        select_many: true
      )

      return if items.empty?

      count_earnings

      fleet_hangar = wait_for(
        { '_setText': ' (Fleet Hangar)' },
        type: 'Label',
        contains: true,
        until: 5
      )

      say('compressing ore')

      items.each do |item|
        click_node(
          item,
          right_click: true,
          expect: [{ '_setText': 'Stack All' }],
          expect_args: { 'type': 'EveLabelMedium' }
        )

        stack_all_btn = wait_for(
          { '_setText': 'Stack All' },
          type: 'EveLabelMedium'
        )

        click_node(stack_all_btn)

        click_node(
          item,
          right_click: true,
          expect: [{ '_setText': 'Select All' }],
          expect_args: { 'type': 'EveLabelMedium' }
        )

        select_all_btn = wait_for(
          { '_setText': 'Select All' },
          type: 'EveLabelMedium'
        )

        click_node(select_all_btn)

        click_node(
          item,
          right_click: true,
          expect: [{ '_setText': 'Compress' }],
          expect_args: {
            'type': 'EveLabelMedium',
            'contains': true
          }
        )

        compress_btn = wait_for(
          { '_setText': 'Compress' },
          type: 'EveLabelMedium',
          contains: true
        )

        click_node(compress_btn)

        confirm_btn = wait_for(
          { '_setText': 'Compress' },
          type: 'LabelThemeColored'
        )

        click_node(confirm_btn, times: 2)

        close_btn = wait_for(
          { '_setText': 'Cancel' },
          type: 'LabelThemeColored'
        )

        click_node(close_btn, times: 2)

        click_node(
          item,
          right_click: true,
          expect: [{ '_setText': 'Select All' }],
          expect_args: { 'type': 'EveLabelMedium' }
        )

        select_all_btn = wait_for(
          { '_setText': 'Select All' },
          type: 'EveLabelMedium'
        )

        drag_node_to_node(item, fleet_hangar)
        break
      end

      break
    end
  end

  def repair
    say('repairing ship')
    repair_facilities = wait_for(
      { '_setText': 'Repair Facilities' },
      until: 5
    )

    unless repair_facilities
      repair_btn = wait_for(
        { '_name': 'repairshop' }
      )

      click_node(
        repair_btn,
        expect: [{ '_setText': 'Repair Facilities' }]
      )
    end

    items_to_repair = wait_for(
      { '_name': 'entryLabel' },
      select_many: true,
      until: 5
    )

    return unless items_to_repair

    items_to_repair.each do |item|
      click_node(item)
    end

    repair_item_btn = wait_for(
      { '_setText': 'Repair Item' }
    )

    click_node(repair_item_btn)
  end

  def warp_to_asteroid_belt
    loop do
      wait_for_overview
      say('Finding asteroid belt for warp target')

      asteroid_belts = wait_for(
        { '_text': ' - Asteroid Belt ' },
        select_many: true,
        contains: true,
        type: 'OverviewLabel'
      )

      self.current_asteroid = asteroid_belts[0]

      asteroid_belt = asteroid_belts.find do |belt|
        belt_attrs = belt.attrs
        next if belt_attrs['_text'].nil?

        belt_name = belt_attrs['_text']

        unless @visited_asteroid_belts.include?(belt_name)
          @visited_asteroid_belts.append(belt_name)
          true
        end
      end

      return -1 unless asteroid_belt

      click_node(asteroid_belt)

      warpto_btn = wait_for(
        { '_name': 'selectedItemWarpTo' },
        type: 'SelectedItemButton'
      )

      click_node(warpto_btn)

      break if wait_for({ '_setText': 'Establishing Warp Vector' }, until: 5)
    end

    wait_until_warp_finished
  end

  def ensure_inventory_is_open
    inv_label = wait_for(
      { '_setText': 'Inventory' },
      type: 'Label',
      until: 5
    )

    return if inv_label

    inv_btn = wait_for(
      { '_name': 'inventory' },
      type: 'ButtonInventory'
    )

    raise 'failed to find inventory button' unless inv_btn

    click_node(
      inv_btn,
      expect: [{ '_setText': 'Inventory' }],
      expect_args: { 'type': 'Label' }
    )
  end

  def ensure_mining_hold_is_open
    ensure_inventory_is_open
    mining_hold = wait_for(
      { '_setText': 'Mining Hold' },
      type: 'Label',
      until: 10
    )

    raise 'failed to find mining hold' unless mining_hold

    sleep(3)
    click_node(mining_hold, times: 2)
  end

  def ensure_cargo_is_open
    ensure_inventory_is_open

    cargo_btn = wait_for(
      { '_name': 'topCont_ShipHangar' },
      type: 'Container'
    )

    click_node(cargo_btn, times: 2)
  end

  def count_earnings
    est_price_node = wait_for(
      { '_setText': 'Est. price' },
      type: 'Label',
      contains: true
    )

    est_price_str = est_price_node.attrs['_setText']
    est_price, _ = est_price_str.split('ISK')
    est_price = est_price.delete(',').to_i
  end

  def unload_loot
    sleep(5)
    say('unloading loot')

    ensure_mining_hold_is_open

    items = wait_for(
      { '_name': 'itemNameLabel' },
      type: 'Label',
      select_many: true
    )

    return unless items

    count_earnings

    item_hangar = wait_for(
      { '_setText': 'Item hangar', '_name': nil },
      type: 'Label'
    )

    raise 'failed to find item hangar' unless item_hangar

    items.each do |item|
      drag_node_to_node(item, item_hangar)
    end
  end

  def deploy_drones
    return unless @deploy_drones_while_mining

    return unless wait_for(
      { '_setText': 'Drones in Space (0)' },
      type: 'EveLabelMedium',
      until: 5
    )

    say('deploying drones')

    drones = wait_for(
      { '_setText': 'Drones in Bay (' },
      type: 'EveLabelMedium',
      contains: true
    )

    click_node(drones, right_click: true)

    launch_btn = wait_for(
      { '_setText': 'Launch Drones' },
      type: 'EveLabelMedium',
      contains: true
    )

    click_node(launch_btn)

    sleep(2)

    return unless wait_for(
      { '_setText': 'Drones in Bay (0)' },
      type: 'EveLabelMedium',
      until: 5
    )

    deploy_drones
  end

  def warp_to_asteroid_belt_if_no_asteroid_of_interest
    asteroids = wait_for(
      { '_text': 'Asteroid (' },
      type: 'OverviewLabel',
      select_many: false,
      contains: true,
      until: 1
    )

    return unless asteroids

    warp_to_asteroid_belt
  end

  def find_asteroids_of_interest
    @asteroids_of_interest.each do |asteroid_type|
      this_list = wait_for(
        { '_text': asteroid_type },
        type: 'OverviewLabel',
        select_many: true,
        contains: false,
        until: 5
      )
      this_list.each { |this_asteroid| @matched_asteroids.append(this_asteroid) }
    end
  end

  def find_closest_asteroid
    loop do
      begin
        asteroids = wait_for(
          { '_text': 'Asteroid (' },
          type: 'OverviewLabel',
          select_many: true
          select_many: true,
          contains: true,
          until: 5
        )

        if (asteroids_len = asteroids.length) > 0
          puts "asteroids len: #{asteroids_len}"
        end

        while asteroids.empty?
          recall_drones if @deploy_drones_while_mining
          return -1 if warp_to_asteroid_belt == -1

          wait_for_overview
          mining_tab = wait_for(
            { '_setText': 'Mining' },
            type: 'EveLabelMedium'
          )
          click_node(mining_tab, times: 1)
          say('finding asteroid')
        end

        closest_asteroid = nil

        asteroids.each do |asteroid|
          _, asteroid_name = asteroid.attrs['_text'].split('(')
          asteroid.data['full_name'] = asteroid_name.delete(')')
          if asteroid.data['full_name'].include?(' ')
            _, asteroid.data['name'] = asteroid.data['full_name'].split(' ')
          else
            asteroid.data['name'] = asteroid.data['full_name']
          end
          puts "asteroid.data name: #{asteroid.data['name']}"
          next unless @asteroids_of_interest.include?(asteroid.data['name'])

          pnode = asteroid.parent
          dnode = pnode.children[5]
          distance_str = dnode.attrs['_text'].to_s
          next unless distance_str.end_with?('m') || distance_str.end_with?('km')

          puts "'#{distance_str}'"
          distance, unit = distance_str.strip.split(' ')
          asteroid.data['distance'] = distance.delete(',').to_i

          if unit == 'm'
            asteroid.data['distance'] /= 1000
          end

          unless closest_asteroid ||
                 (asteroid.attrs['_text'].include?('Massive') &&
                  asteroid.data['distance'] < 15) ||
                 (asteroid.attrs['_text'].exclude?('Massive') &&
                  asteroid.data['distance'] < closest_asteroid.data['distance'])
            next
          end

          closest_asteroid = asteroid
        end

        @current_asteroid = closest_asteroid
        return closest_asteroid if closest_asteroid
      rescue StandardError => e
        puts e.backtrace
        say('trying to recover from error')
        next
      end
    end
  end

  def check_for_locked_asteroid
    wait_for(
      { '_name': 'assigned' },
      type: 'Container',
      until: 1
    )
  end

  def find_asteroid
    wait_for_overview
    mining_tab = wait_for(
      { '_setText': 'Mining' },
      type: 'EveLabelMedium'
    )

    click_node(mining_tab, times: 1)
    warp_to_asteroid_belt_if_no_asteroid_of_interest
    @current_asteroid = nil
    say('finding asteroid')

    while (target_locked = check_for_locked_asteroid).nil?
      find_asteroids_of_interest if @current_asteroid.nil?

      unless @current_asteroid
        @current_asteroid = @matched_asteroids[0]
        click_node(@current_asteroid)
      end

      name = @current_asteroid.attrs['_text']
      selected_item_info = wait_for(
        { '_setText': "Asteroid (#{name})<br>" },
        type: 'EveLabelMedium',
        contains: true
      )
      _, dist_with_unit = selected_item_info.attrs['_setText'].split('<br>')
      distance_str, unit = dist_with_unit.split(' ')
      distance = distance_str.delete(',').to_i

      track_btn = wait_for(
        { '_name': 'selectedItemSetInterest' },
        type: 'SelectedItemButton'
      )

      if track_btn.nil?
        target_locked = false
      end

      click_node(track_btn)

      if distance > 2000 && distance <= 9999 && unit == 'm'
        stop_button = wait_for(type: 'StopButton', until: 1)
        click_node(stop_button)

        lock_target_btn = wait_for(
          { '_name': 'selectedItemLockTarget' },
          type: 'SelectedItemButton'
        )

        if lock_target_btn
          click_node(lock_target_btn)
          say('Target locked')
          break
        end
      elsif distance >= 10 && unit == 'km'
        approach_btn = wait_for(
          { '_name': 'selectedItemApproach' },
          type: 'SelectedItemButton'
        )

        click_node(approach_btn)
      elsif distance <= 2000 && unit == 'm'
        stop_button = wait_for(type: 'StopButton', until: 1)
        click_node(stop_button)

        lock_target_btn = wait_for(
          { '_name': 'selectedItemLockTarget' },
          type: 'SelectedItemButton',
          until: 1
        )

        if lock_target_btn
          click_node(lock_target_btn)
          say('Target locked')
        end

        break
      end
    end
  end

  def change_miner(slot)
    return -1 unless ensure_cargo_is_open

    items = wait_for(
      { '_name': 'itemNameLabel' },
      type: 'Label',
      until: 5,
      select_many: true
    )

    return -1 unless items

    miner_stash = nil

    items.each do |item|
      item_parent = @tree.nodes[item.parent]
      item_grandparent = @tree.nodes[item_parent.parent]
      item_quantity_parent = @tree.nodes[item_grandparent.children[2]]

      next unless item_quantity_parent.type == 'ContainerAutoSize'

      item_quantity = @tree.nodes[item_quantity_parent.children[0]]

      next unless item_quantity.type == 'EveLabelSmall'

      quantity = item_quantity.attrs['_setText'].to_i

      if quantity > 1
        miner_stash = item
        break
      end
    end

    return -1 unless miner_stash

    drag_node_to_node(miner_stash, slot)
  end

  def check_if_miner_is_damaged(slot)
    move_cursor_to_node(slot)
    sleep(2)

    damaged_str = wait_for(
      { '_setText': 'Damaged' },
      type: 'EveLabelMedium',
      contains: true,
      until: 5
    )

    if damaged_str
      if damaged_str.attrs['_setText'].include?('<color=red>')
        _, damaged_percentage_str = damaged_str.attrs['_setText'].split('<color=red>')
        percentage_str, _ = damaged_percentage_str.split(' ')
        percentage = percentage_str.delete('%').to_i

        if percentage >= 90
          change_miner(slot)
          sleep(5)
        end
      end
    end
  end

  def mine_asteroid
    return unless wait_for({ '_setText': 'Asteroid' }, until: 5)

    change_miner_slot = wait_for(
      { '_setText': 'Fitted Module: Modulated Strip Miner II' },
      type: 'Label',
      until: 5
    )

    return unless change_miner_slot

    miner_slot = @tree.nodes[change_miner_slot.parent]
    check_if_miner_is_damaged(miner_slot)

    mine_btn = wait_for(
      { '_setText': 'Mine' },
      type: 'Button',
      until: 5
    )

    click_node(mine_btn)

    hauler_name = @tree.nodes[2].attrs['_text']
    hauler_distance_str = @tree.nodes[3].attrs['_text']
    hauler_distance = hauler_distance_str.delete(' km').to_i

    while hauler_name.include?('Hauler') && hauler_distance > 15
      sleep(5)
      hauler_name = @tree.nodes[2].attrs['_text']
      hauler_distance_str = @tree.nodes[3].attrs['_text']
      hauler_distance = hauler_distance_str.delete(' km').to_i
    end
  end

  def mine_asteroid_belt
    @matched_asteroids = []

    while true
      say('Mining asteroid belt')

      if find_asteroid == -1
        wait_for(
          { '_setText': 'There are no asteroid belts in this system.' },
          type: 'EveLabelMedium',
          until: 5
        )
        return
      end

      loop do
        mine_asteroid
        break if check_if_asteroid_depleted ==  -1
      end

      warp_to_asteroid_belt
    end
  end

  def check_if_asteroid_depleted
    say('checking if asteroid is depleted')

    asteroid_empty_label = wait_for(
      { '_setText': 'This asteroid has been depleted' },
      type: 'EveLabelMedium',
      until: 5
    )

    return -1 unless asteroid_empty_label

    asteroid_empty_okay_btn = wait_for(
      { '_setText': 'OK' },
      type: 'Button',
      until: 5
    )

    click_node(asteroid_empty_okay_btn)
  end
end


