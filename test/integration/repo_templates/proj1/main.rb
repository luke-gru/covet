class Main
  attr_reader :result
  def initialize(initial: 0)
    @result = initial
  end
  def add(num)
    @result += num
  end
end
