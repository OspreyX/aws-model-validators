module Aws::ModelValidators
  class WaitersV2

    include Validator

    # unknown_operation
    v('/waiters/*/operation') do |c|
      unless c.api['operations'].key?(c.value)
        c.error("references operation not defined at api#/operations/#{c.value}")
      end
    end

    # missing_success_state
    v('/waiters/*/acceptors') do |c|
      states = c.value.map { |acceptor| acceptor['state'] }
      unless states.include?('success')
        c.error("must define at least one acceptor with a success state")
      end
    end

  end
end
