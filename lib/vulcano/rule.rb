# encoding: utf-8
# copyright: 2015, Dominik Richter
# license: All rights reserved
# author: Dominik Richter
# author: Christoph Hartmann

require 'rspec/expectations'

module Vulcano
  class ExpectationTarget
    attr_reader :calls, :value, :block
    def initialize(value, &block)
      @value = value
      @block = block
      @calls = []
    end

    def to(*args, &block)
      @calls.push([:to, args, block, caller])
    end

    def not_to(*args, &block)
      @calls.push([:not_to, args, block, caller])
    end

    def example_group
      that = self
      outer_clr = calls[0][3]
      RSpec::Core::ExampleGroup.describe(that.value, caller: outer_clr) do
        that.calls.each do |method, args, block, clr|
          it(nil, caller: clr) do
            x = expect(that.value, &that.block).method(method)
            x.call(*args, &block)
          end
        end
      end
    end
  end

  class Rule
    include ::RSpec::Matchers

    def initialize(id, _opts, &block)
      @id = id
      @impact = nil
      @__code = ''
      @__block = block
      @title = nil
      @desc = nil
      # not changeable by the user:
      @profile_id = nil
      @checks = []
      # evaluate the given definition
      instance_eval(&block) if block_given?
    end

    def id(*_)
      # never overwrite the ID
      @id
    end

    def impact(v = nil)
      @impact = v unless v.nil?
      @impact
    end

    def title(v = nil)
      @title = v unless v.nil?
      @title
    end

    def desc(v = nil)
      @desc = unindent(v) unless v.nil?
      @desc
    end

    def describe(value, &block)
      @checks.push(['describe', [value], block])
    end

    def expect(value, &block)
      target = ExpectationTarget.new(value, &block)
      @checks.push(['expect', [value], target])
      target
    end

    def self.merge(dst, src)
      if src.id != dst.id
        # TODO: register an error, this case should not happen
        return
      end
      sp = src.instance_variable_get(:@profile_id)
      dp = dst.instance_variable_get(:@profile_id)
      if sp != dp
        # TODO: register an error, this case should not happen
        return
      end
      # merge all fields
      dst.impact(src.impact) unless src.impact.nil?
      dst.title(src.title)   unless src.title.nil?
      dst.desc(src.desc)     unless src.desc.nil?
      # merge indirect fields
      # checks defined in the source will completely eliminate
      # all checks that were defined in the destination
      sc = src.instance_variable_get(:@checks)
      unless sc.nil? || sc.empty?
        dst.instance_variable_set(:@checks, sc)
      end
    end

    # Get the full id consisting of profile id + rule id
    # for the rule. If the rule's profile id is empty,
    # the given profile_id will be used instead and also
    # set for the rule.
    def self.full_id(profile_id, rule)
      if rule.is_a?(String) or rule.nil?
        rid = rule
      else
        # As the profile context is exclusively pulled with a
        # profile ID, attach it to the rule if necessary.
        rid = rule.instance_variable_get(:@id)
        if rid.nil?
          # TODO: Message about skipping this rule
          # due to missing ID
          return nil
        end
      end
      pid = rule.instance_variable_get(:@profile_id)
      if pid.nil?
        rule.instance_variable_set(:@profile_id, profile_id)
        pid = profile_id
      end
      if pid.nil? or pid.empty?
        return rid
      else
        return "#{pid}/#{rid}"
      end
    end

    private

    # Idio(ma)tic unindent
    # TODO replace this
    #
    # @param [String] text string which needs to be unindented
    # @return [String] input with indentation removed
    def unindent(text)
      return '' if text.nil?
      text.strip.split("\n").map(&:strip)
        .map { |x| x.empty? ? "\n" : x }
        .join(' ')
    end
  end
end
