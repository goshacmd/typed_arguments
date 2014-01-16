module TypedArguments
  VERSION = '0.0.1'

  class << self
    attr_accessor :current_guard, :defining

    # Define a guard and wrap the method.
    #
    # @param type [Symbol] method type (either +:instance+ or +:singleton+)
    # @param method [Method, UnboundedMethod]
    def define(type, method)
      if !self.defining && pg = self.current_guard
        self.defining = true
        Guard.new(type, method, pg).wrap!
        self.defining = false
        self.current_guard = nil
      end
    end
  end

  # Method guard.
  class Guard
    attr_reader :type, :original_method, :name, :owner, :types

    # Initialize a new +Guard+.
    #
    # @param type [Symbol]
    # @param original_method [Method, UnboundedMethod]
    # @param spec [Array<Class>]
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

    def instance?
      type == :instance
    end

    # Get original class/method name.
    #
    # @return [String]
    def original
      [owner.name, name].join(instance? ? '#' : '.')
    end

    # Wrap the original method with guard.
    #
    # @return [void]
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

      new = @type == instance? ? new_inst : new_sing

      @owner.send(:define_method, @name, &new)
    end

    # Ensure passed arguments satisfy guard spec.
    #
    # @param args [Array] array of arguments
    def ensure_matches(*args)
      res = @params.zip(args).map do |(type, name), arg|
        [name, type, type === arg]
      end

      invalid = res.reject(&:last)

      unless invalid.empty?
        str = invalid.map { |name, type| "argument '#{name}' to be of type #{type}" }
        raise ArgumentError, "expected #{str.join(', ')}"
      end
    end
  end
end

class Array
  # Set the guard to array contents.
  #
  # @example
  #   +[Integer]
  def +@
    TypedArguments.current_guard = self.dup
  end
end

class Object
  # Attempt to wrap a freshly-created method in a guard.
  def self.method_added(name)
    super

    TypedArguments.define(:instance, instance_method(name))
  end

  # Attempt to wrap a freshly-created method in a guard.
  def self.singleton_method_added(name)
    super

    TypedArguments.define(:singleton, method(name))
  end
end
