require 'ffi'

module WindowUtils
  extend FFI::Library
  ffi_lib 'user32'
  attach_function :get_system_metrics, :GetSystemMetrics, [:int], :int
end

def get_screensize
  [WindowUtils.get_system_metrics(0), WindowUtils.get_system_metrics(1)]
end

def with_node(query: {}, address: nil, select_many: false, contains: false)
  lambda do |func|
    lambda do |tree|
      node = tree.find_node(query, address, select_many, contains)
      func.call(tree, node)
    end
  end
end

def window_enumeration_handler(hwnd, top_windows)
  top_windows << [hwnd, FFI::MemoryPointer.new(:char, 256).read_string(win32gui.GetWindowText(hwnd))]
end

# Example usage:
#width, height = WindowSize.get_dimensions
#puts "Width: #{width}, Height: #{height}"
#s_width, s_height = get_screensize()
#puts "Screen Width: #{s_width}, Screen Height: #{s_height}"


