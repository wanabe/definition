#! /usr/local/bin/ruby
# -*- coding: UTF-8 -*-

class DefinitionError < StandardError
end
class Definition
  module Const
    module Block
    end
    module Rest
    end
    module Any
      def self.===(other)
        true
      end
    end
  end
  class Enroller
    def initialize(defn, table)
      @defn = defn
      @table = table
    end
    def method_missing(name, *args)
      @defn.set(args)
      @table[name] ||= []
      @table[name] << @defn
    end
  end

  attr_reader :arity
  def initialize(ret_type, root)
    @ret_type = ret_type
    @root = root
  end
  def to_enroll(table)
    Enroller.new(self, table)
  end
  def assert_match(name, meth, implement)
    begin
      if meth.respond_to?(:parameters)
        if meth.parameters.length != @arg_types.length
          message = "%s: arity mismatch (%i for %i)"
          raise DefinitionError, message, name, meth.parameters.length,
          @arg_types.length
        end
        meth.parameters.each_with_index do |param, i|
          type, var = param
          arg_type = @arg_types[i]
          case type
          when :req, :opt
            next if arg_type != Const::Rest && arg_type != Const::Block
          when :rest
            next if arg_type == Const::Rest
          when :block
            next if arg_type == Const::Block
          end
          raise DefinitionError, "%s: arg %i: definition mismatch", name, i
        end
      elsif meth.arity != @arity
        message = "%s: arity mismatch (%i for %i)"
        raise DefinitionError, message, name, meth.arity, @arity
      end
    rescue DefinitionError
      implement.module_eval { remove_method(name) }
      Kernel.raise
    end
  end
  def set(arg_types)
    @arg_types = arg_types
    @arity = arg_types.length
    if arg_types.last == Const::Block
      @arity -= 1
      @block = true
    end
    @arity = -@arity if arg_types.include?(Const::Rest)
  end
  def assert_args(args)
    start_index = 0
    length = args.length
    args.each_with_index do |arg, i|
      next if i < start_index
      break if i >= length
      arg_type = @arg_types[i]
      if arg_type == Definition::Const::Rest
        start_index = @arity + args.length + i + 1
      elsif !(arg_type === arg)
        raise ArgumentError, "arg %i: not %p === %p", i, arg_type, arg
      end
    end
  end
  def assert_ret(ret)
    ret_type = @ret_type
    unless ret_type === ret
      raise TypeError, "return value: not %p === %p", ret_type, ret
    end
  end
  def raise(exclass, message, *args)
    message = sprintf(message, *args)
    if @root.ancestors.include? Interface
      message << " (interface #{@root})"
    else
      message << " (implementation #{@root})"
    end
    super exclass, message
  end
end
module Interface
  include Definition::Const
  module InterfaceMethods
    def included(mod)
      mod.extend InterfaceMethods
      mod.init_table @define_table
    end
    def init_table(table)
      @define_table ||= {}
      if table
        table.each do |name, defs|
          @define_table[name] = defs.dup
        end
      end
    end
    def each(&block)
      @define_table.each(&block)
    end
    def define(ret=Definition::Const::Any)
      defn = Definition.new(ret, self)
      return defn.to_enroll(@define_table)
    end
    def [](name)
      return @define_table[name]
    end
  end
  extend InterfaceMethods
end
module Implementation
  include Definition::Const
  def self.included(klass)
    klass.module_eval do
      extend Implementation::ImplMethods
      impl_initialize
    end
  end
  module ImplMethods
    NEW = Class.instance_method(:new)
    def new
      assert_implemented unless @skip_assertion
      NEW.bind(self).call
    end
    def define(ret=Definition::Const::Any)
      defn = Definition.new(ret, self)
      return defn.to_enroll(@define_table)
    end
    def implement(interface)
      interface.each do |name, defs|
        @define_table[name] ||= []
        @define_table[name] += defs
      end
    end
    def assert_implemented(once = false)
      nodefs = @define_table.keys - instance_methods(true).map{|m|m.to_sym}
      unless nodefs.empty?
        raise NotImplementedError, "not implemented #{nodefs.join(', ')}"
      end
      @skip_assertion ||= once
    end
    def assert_args(name, args)
      defns = @define_table[name]
      defns.each {|defn| defn.assert_args(args)}
    end
    def assert_ret(name, ret)
      defns = @define_table[name]
      defns.each {|defn| defn.assert_ret(ret)}
      return ret
    end
    def impl_initialize(table = {})
      @define_table = table
    end
    private
    def included(klass)
      klass.extend Implementation::ImplMethods
      inherited(klass)
    end
    def inherited(klass)
      klass.impl_initialize(@define_table)
      assert_implemented
    end
    def method_added(name)
      return if @in_addition_check
      begin
        @in_addition_check = true
        check_definition(name)
        add_assertion(name)
      ensure
        @in_addition_check = false
      end
    end
    def check_definition(name)
      @define_table[name].each do |defn|
        defn.assert_match name, instance_method(name), self
      end
    end
    def add_assertion(name)
      num = 0
      new_name = name
      new_name = "#{name}_#{num += 1}" while method_defined?(new_name)
      alias_method new_name, name
      module_eval <<-EOC, __FILE__, __LINE__ + 1
      def #{name}(*args, &block)
        self.class.assert_args(:#{name}, args)
        self.class.assert_ret(:#{name}, #{new_name}(*args, &block))
      end
      EOC
    end
  end
end
class Module
  def implement(*interfaces)
    as_implementation
    interfaces.each do |interface|
      implement(interface)
    end
  end
  def define(ret=Definition::Const::Any)
    as_implementation
    define(ret)
  end
  private
  def as_implementation
    include Implementation unless include?(Implementation)
  end
  def as_interface
    include Interface unless include?(Interface)
  end
end

if __FILE__ == $0
  $" << "definition.rb"
  load "../test/tc_definition.rb"
end
