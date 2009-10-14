class Array
  def all_indices
   (0...self.size).to_a
  end
  
  def assigned_indices
    all_indices.reject { |i| self[i].nil? }
  end
  
  def prefix(str)
    self.map { |item| "#{str}#{item}" }
  end
  
  def prefix!(str)
    self.map! { |item| "#{str}#{item}" }
  end
  
  def postfix(str)
    self.map { |item| "#{item}#{str}" }
  end
  
  def postfix!(str)
    self.map! { |item| "#{item}#{str}" }
  end
  
  def map_with_indices(target = [])
    self.each_index do |index|
      target[index] = yield(self[index], index)
    end
    target
  end
  
  def map_with_indices!
    self.map_with_indices(self)
  end
  
  def map_method_results(method_name, *args, &block)
    self.map { |item| item.__send__(method_name, *args, &block) }
  end
  
  def map_method_results!(method_name, *args, &block)
    self.map! { |item| item.__send__(method_name, *args, &block) }
  end
  
  alias_method :throw_method_missing, :method_missing
  def method_missing(name, *args, &block)
    if name.to_s[-1..-1] == 's'
      method_name = name.to_s[0..-2].to_sym
      if size == 0 || self[0].respond_to?(method_name)
        return map_method_results(method_name, *args, &block)
      end
    end
    throw_method_missing(name, args, &block)
  end
  
  class Eachy
    def target=(value)
      @target = value
    end
    
    def method_missing(name, *args, &block)
      @target.map_method_results(name, *args, &block)
    end
  end
  
  def call_each(&block)
    eachy = Eachy.new
    eachy.target = self
    eachy
  end
  
  def reject_nils
    self.reject { |item| item.nil? }
  end
  
  def reject_nils!
    self.reject! { |item| item.nil? }
  end
end

class String
  def to_a
    [self]
  end
end

class SynchronizableArray < Array
  include Mutex_m
end

class SynchronizableHash < Hash
  include Mutex_m
end