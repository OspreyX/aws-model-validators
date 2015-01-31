require 'json'
require 'json-schema'
require 'pathname'

module Aws
  module ModelValidators
    class Validator

      extend LoadJson

      # @param [Hash] models A map of AWS models. Hash keys should be
      #   symbols and values should be loaded JSON hashes or string paths
      #   to JSON documents. Valid hash keys include:
      #
      #   * `:api`
      #   * `:paginators`
      #   * `:waiters`
      #   * `:resources`
      #
      # @param [Hash<Symbol,Hash>] models
      # @option options [Boolean] :apply_schema (true)
      def validate(models = {}, options = {})
        models = load_models(models)
        errors = []
        errors = validate_schema(models) unless options[:apply_schema] == false
        if errors.empty?
          validate_rules(new_context(models))
        else
          errors
        end
      end

      private

      def load_models(models)
        models.inject({}) { |h,(k,v)| h[k] = self.class.load_json(v); h }
      end

      def new_context(models)
        Context.new(value:target(models), models:models)
      end

      def target(models)
        models[self.class.model_name]
      end

      def validate_schema(models)
        errors = JSON::Validator.fully_validate(self.class.schema, target(models))
        format_schema_errors(errors)
      end

      def validate_rules(context)
        self.class.rules.each do |rule|
          if matches = rule.matches(context.path)
            rule.apply(context, matches)
          end
        end
        validate_hash(context) if Hash === context.value
        validate_array(context) if Array === context.value
        context.results
      end

      def validate_hash(context)
        context.value.keys.each do |key|
          validate_rules(context.child(key))
        end
      end

      def validate_array(context)
        (0...context.value.size).each do |index|
          validate_rules(context.child(index))
        end
      end

      def format_schema_errors(errors)
        errors.map do |msg|
          msg = msg.sub(/^The property '/, '')
          msg = msg.sub(/'/, '')
          msg = msg.sub(/ in schema \S+$/, '')
          path = msg.split(' ').first
          ErrorMessage.new(path, msg[(path.size+1)..-1])
        end
      end

      class << self

        def model_name
          @model_name
        end

        def schema
          @schema
        end

        def rules
          @rules
        end

        # Adds a validation rule for the given patterns.
        def validate(*patterns, &block)
          patterns.flatten.each do |pattern|
            @rules << Rule.new(pattern, &block)
          end
        end
        alias v validate

        def inherited(sub_class)
          name = sub_class.name.split('::').last.downcase.to_sym
          schema = File.expand_path("../../../schemas/#{name}.json", __FILE__)
          schema = Pathname.new(schema)
          sub_class.instance_variable_set("@model_name", name)
          sub_class.instance_variable_set("@schema", load_json(schema))
          sub_class.instance_variable_set("@rules", [])
        end

      end
    end
  end
end
