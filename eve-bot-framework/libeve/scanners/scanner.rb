class Scanner
  def initialize
    # Your initialization code here
  end
end

class EnemyScanner < Scanner
  def initialize
    # Your initialization code here
  end
end

registered_scanners = { "EnemyScanner" => EnemyScanner.new }

