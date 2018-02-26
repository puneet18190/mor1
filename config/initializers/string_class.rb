class String
    # checks if given string is an integer
    def is_i?
       !!(self =~ /\A[-+]?[0-9]+\z/)
    end
end
