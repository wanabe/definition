# -*- coding: UTF-8 -*-
require 'test/unit'
require 'rubygems'
require 'definition'

class TC_Foo < Test::Unit::TestCase
  module IFoo
    as_interface
    define::foo(Integer, String, Rest, Block)
  end
  module IBar
    as_interface
    define(Any).bar(Integer)
  end
  module IFooBar
    include IFoo, IBar
    define.foo(10..20, Any, Rest, Block)
  end
  module IBar2
    include IBar
    define(Any).bar(0..10)
  end

  def test_arity
    mismatch_arity_class = Class.new
    mismatch_arity_class.implement IFoo
    
    assert_raise(DefinitionError) do
      mismatch_arity_class.module_eval do
        implement IFoo
        def foo(a, b, c, *d, &e)
        end
      end
    end
    assert_raise(DefinitionError) do
      mismatch_arity_class.module_eval do
        def foo(a, *b, &c)
        end
      end
    end
  end
  def test_after_rescue
    defective_module = Module.new
    defective_class = Class.new
    defective_module.implement IFoo
    
    assert_raise(NotImplementedError) do
      defective_class.module_eval do
        include defective_module
      end
    end
    assert_raise(NotImplementedError) do
      defective_class.new
    end
  end
  def test_rest
    mismatch_rest_class1 = Class.new
    mismatch_rest_class1.implement IFoo
    mismatch_rest_class2 = Class.new
    mismatch_rest_class2.implement IBar
    
    assert_raise(DefinitionError) do
      mismatch_rest_class1.module_eval do
        def foo(a, b, c, &d)
        end
      end
    end
    assert_raise(DefinitionError) do
      mismatch_rest_class1.module_eval do
        def foo(a, b, &d)
        end
      end
    end
    assert_raise(DefinitionError) do
      mismatch_rest_class2.module_eval do
        def bar(a, *b)
        end
      end
    end
    assert_raise(DefinitionError) do
      mismatch_rest_class2.module_eval do
        def bar(*a)
        end
      end
    end
  end
  def test_correct
    correct_class = Class.new
    correct_class.implement IFoo
    
    assert_nothing_raised do
      correct_class.module_eval do
        def foo(a, b, *c, &d)
        end
      end
      correct_class.new.foo(1, "a")
    end
  end
  def test_defective
    defective_class = Class.new
    defective_class.module_eval do
      define(String).baz
    end
    
    assert_raise(NotImplementedError) do
      Class.new(defective_class)
    end
    assert_raise(NotImplementedError) do
      defective_class.new
    end
  end
  def test_retval
    baz_class = Class.new
    baz_class.module_eval do
      define(String).baz
      def baz
        :ng
      end
    end
    
    assert_raise(TypeError) do
      baz_class.new.baz
    end
    baz_class.module_eval do
      def baz
        "ok"
      end
    end
    assert_equal(baz_class.new.baz, "ok")
  end
  def test_argument
    foobar_class = Class.new
    foobar_class.module_eval do
      implement IFooBar, IBar2
      def foo(a, b, *c, &d)
      end
      def bar(a)
      end
    end
    o = foobar_class.new
    assert_raise(ArgumentError) do
      o.foo(1,"a")
    end
    assert_raise(ArgumentError) do
      o.foo(10,2)
    end
    assert_raise(ArgumentError) do
      o.bar(:ng)
    end
    assert_raise(ArgumentError) do
      o.bar(-1)
    end
    assert_nothing_raised do
      o.foo(10,"a")
      o.bar(1)
    end
  end
  if RUBY_VERSION >= "1.9"
    def test_arg_after_rest
      class_arg_after_rest = Class.new
      class_arg_after_rest.module_eval do
        define.foo(Any, Rest, Range)
      end
      assert_raise(DefinitionError) do
        class_arg_after_rest.module_eval do
          def foo(a, *b)
          end
        end
      end
      assert_raise(DefinitionError) do
        class_arg_after_rest.module_eval do
          def foo(a, b, *c)
          end
        end
      end
      assert_nothing_raised do
        class_arg_after_rest.module_eval do
          eval "def foo(a, *b, c);end"
        end
      end
    end
    def test_block
      assert_raise(DefinitionError) do
        Class.new.module_eval do
          define.foo
          def foo(&a)
          end
        end
      end
    end
  end
end
