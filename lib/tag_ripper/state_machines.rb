# frozen_string_literal: true

module TagRipper
  # Defines a finite state machine. Opted for this, rather than a third party
  # solution like AASM, so that there aren't any depdendency clashes
  module StateMachines # :nodoc:
    class IllegalStateTransitionError < StandardError; end

    # Prepend the state machine initialization onto the extending class
    module StateMachineInitialization # :nodoc:
      def initialize(...)
        self.status = self.class.state_names.first if self.class.state_machine
        super
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.prepend(StateMachineInitialization)
    end

    def state_machine
      self.class.state_machine
    end

    module ClassMethods # :nodoc:
      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def state_machine(&)
        return @state_machine unless block_given?

        @state_machine = StateMachine.new(&)

        state_names.each do |state_name|
          define_method(:"#{state_name}?") do
            status == state_name
          end
        end

        state_machine.events.each do |event_name, event|
          define_method(:"may_#{event_name}?") do
            event.defined_transitions.any? do |t|
              t[:from] == status.to_sym ||
                t[:to] == status.to_sym # allow transition to same state
            end
          end

          define_method(:"#{event_name}!") do
            transition = event.defined_transitions.find do |t|
              t[:from] == status.to_sym
            end
            may_transition_via_event = public_send(:"may_#{event_name}?")
            unless may_transition_via_event
              raise IllegalStateTransitionError,
                    "Invalid transition: " \
                    "Cannot transition via #{event_name} from #{status.to_sym}"
            end

            return status if may_transition_via_event & transition.nil?

            self.status = transition[:to].to_sym
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def state_names
        @state_machine.states
      end
    end

    class StateMachine # :nodoc:
      attr_reader :states
      attr_reader :events

      def initialize(&)
        @states = Set.new
        @events = {}
        instance_eval(&)
      end

      def state(name)
        @states.add(name.to_sym)
      end

      def event(name, &)
        @events[name.to_sym] = Event.new(name)
        @events[name.to_sym].instance_eval(&)
      end

      class Event # :nodoc:
        ##
        # Name of the method that triggers a state transition
        # @return [Symbol]
        attr_reader :name

        ##
        # @return [Array<Hash>] Defined state machine transitions
        attr_reader :defined_transitions

        def initialize(name)
          @name = name
          @defined_transitions = []
        end

        def transitions(from:, to:)
          @defined_transitions << { from: from.to_sym, to: to.to_sym }
        end
      end
      private_constant :Event
    end
  end
end
