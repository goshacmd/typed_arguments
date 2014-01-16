module TypedArguments
  VERSION = '0.0.1'

  class << self
    attr_accessor :previous_guard, :defining

    def define(type, method)
      if !self.defining && pg = self.previous_guard
        puts "defining #{type} #{method}"
        self.defining = true
        Guard.new(type, method, pg).wrap!
        self.defining = false
        self.previous_guard = nil
      end
    end
  end

  class Guard
    def initialize(type, original_method, spec)
      @type = type
      @original_method = original_method
      @name = original_method.name
      @owner = original_method.owner
      @types = spec

      unless @original_method.arity == @types.size
        raise RuntimeError, "#{@name} has arity of #{@original_method.arity} but guard spec assumes #{@types.size}"
      end

      @params = @types.zip(original_method.parameters).map do |arg_type, (_, name)|
        [arg_type, name]
      end
    end

    def original
      [@owner.name, @name].join(@type == :instance ? '#' : '.')
    end

    def wrap!
      this = self
      m = @original_method

      new_sing = lambda do |*args|
        this.ensure_matches(*args)
        m.call(*args)
      end

      new_inst = lambda do |*args|
        this.ensure_matches(*args)
        m.bind(self).call(*args)
      end

      new = @type == :instance ? new_inst : new_sing

      @owner.send(:define_method, @name, &new)
    end

    def ensure_matches(*args)
      res = @params.zip(args).map do |(type, name), arg|
        [name, type, type === arg]
      end

      invalid = res.reject(&:last)

      unless first = invalid.first
        raise ArgumentError, "expected argument '#{first[0]}' to be of type #{first[1]}"
      end
    end

    def matches?(*args)
      @types.size == args.size && @types.zip(args).all? { |t, a| t === a }
    end
  end
end

class Array
  def +@
    TypedArguments.previous_guard = self.dup
  end
end

class Object
  def self.method_added(name)
    super

    TypedArguments.define(:instance, instance_method(name))
  end

  def self.singleton_method_added(name)
    super

    TypedArguments.define(:singleton, method(name))
  end
end
