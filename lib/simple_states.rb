require 'simple_states/states'

module SimpleStates
  class Error < RuntimeError; end

  class << self
    def included(const)
      states = const.const_set(:States, States.new)
      const.send(:prepend, states) if const.respond_to?(:prepend)
      const.extend(ClassMethods)
      const.initial_state = :created
      const.after_initialize(:init_state) if const.respond_to?(:after_initialize)
    end
  end

  module ClassMethods
    attr_accessor :initial_state

    def new(*)
      super.tap { |object| object.init_state }
    end

    def event(name, opts = {})
      method = name == :all ? :update_events : :define_event
      self::States.send(method, name, opts)
    end

    def state?(state)
      states.include?(state)
    end

    def states
      [initial_state] + self::States.states
    end
  end

  def init_state
    singleton_class.send(:include, self.class::States) unless self.class.respond_to?(:prepend)
    self.state = self.class.initial_state if self.state.nil?
  end

  def state=(state)
    super(state.to_sym)
  end

  def state
    state = super
    state.to_sym if state
  rescue ActiveModel::MissingAttributeError
    nil
  end

  def state?(state)
    self.state.to_sym == state.to_sym
  end

  def reset_state
    self.state = self.class.initial_state
    self.class::States.events.map { |_, event| event.reset(self) }
  end

  def respond_to?(name)
    state = name.to_s[0..-2].to_sym
    name.to_s[-1] == '?' && self.class.state?(state) || super
  end

  def method_missing(name, *args)
    state = name.to_s[0..-2].to_sym
    return super unless name.to_s[-1] == '?' && self.class.state?(state)
    state?(state)
  end
end
