require 'ffi'
require 'json'
require_relative 'utils.rb'

module EVE
  extend FFI::Library
  ffi_lib './eve-memory-reader.dll'

  attach_function :initialize, [], :int
  attach_function :read_ui_trees, [], :void
  attach_function :get_ui_json, [], :string
  attach_function :free_ui_json, [], :void
  attach_function :cleanup, [], :void
end

class UITreeNode
  attr_accessor :address, :type, :attrs, :x, :y, :parent, :data, :children

  def initialize(node)
    @address = node['address']
    @type = node['type']
    @attrs = node['attrs'] || {}
    @x = node['x'] || 0
    @y = node['y'] || 0
    @parent = node['parent']
    @data = {}
    @children = node['children'].to_a.map { |child| child['address'] }
  end
end

class UITree
  attr_accessor :nodes, :width_ratio, :height_ratio

  def initialize
    @nodes = {}
    @width_ratio = 0
    @height_ratio = 0

    ret = EVE.initialize
    raise "Failed to initialize: #{ret}" unless ret.zero?

    refresh
  end

  def cleanup
    EVE.cleanup
  end

  def ingest(tree, x = 0, y = 0, parent = nil)
    node = UITreeNode.new(tree.merge('x' => x, 'y' => y, 'parent' => parent))
    @nodes[node.address] = node
    tree['children'].to_a.each do |child|
      real_x = x + (child['attrs']['_displayX'] || 0)
      real_y = y + (child['attrs']['_displayY'] || 0)
      ingest(child, real_x, real_y, tree['address'])
    end
  end

  def load(tree)
    @nodes = {}
    ingest(tree)
    begin
      raise ZeroDivisionError if tree['attrs']['_displayWidth'].nil? || tree['attrs']['_displayHeight'].nil?

      screensize = get_screensize
      @width_ratio = screensize[0] / tree['attrs']['_displayWidth']
      @height_ratio = screensize[1] / tree['attrs']['_displayHeight']
    rescue ZeroDivisionError
      refresh
    end
  end

  def refresh
    EVE.read_ui_trees
    tree_bytes = EVE.get_ui_json
    EVE.free_ui_json
    return puts('no ui trees found') unless tree_bytes

    begin
      tree_str = tree_bytes.force_encoding('utf-8').encode('utf-8', invalid: :replace, undef: :replace, replace: '')
      File.write('super.debug.json', tree_str)
      tree = JSON.parse(tree_str)
      load(tree)
      File.write('debug.json', JSON.pretty_generate(tree))
    rescue StandardError => e
      puts "error reading ui trees: #{e}"
    end
  end

  def find_node(query = {}, address = nil, type = nil, select_many = false, contains = false)
    refresh
    nodes = []

    @nodes.each do |_, node|
      next if address && node.address != address
      next if type && node.type != type

      if query.all? { |qkey, qval| !contains ? node.attrs[qkey] == qval : node.attrs[qkey].to_s.include?(qval.to_s) }
        nodes.push(node)
        break unless select_many
      end
    end

    return nodes[0] if nodes.any? && !select_many

    nodes
  end
end

