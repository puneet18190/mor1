module UtilityHelper
  def self.random_password(size = 12)
    chars = (('a'..'z').to_a + (0..9).to_a) - %w(i o 0 1 l 0)
    (1..size).collect { |char| chars[rand(chars.size)] }.join
  end

  def full_name
    if self.first_name && self.last_name
      self.first_name.capitalize + ' ' + self.last_name.capitalize
    else
      self.username
    end
  end
end