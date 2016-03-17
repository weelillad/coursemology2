# frozen_string_literal: true
module Extensions::Conditional::ActiveRecord::Base
  module ClassMethods
    # Functions from conditional-and-condition framework.
    # Declare this function in the conditional model that requires conditions.
    def acts_as_conditional
      has_many :conditions, -> { includes :actable },
               class_name: Course::Condition.name, as: :conditional, dependent: :destroy,
               inverse_of: :conditional

      include ConditionalInstanceMethods
    end

    # Declare this function in the condition model
    def acts_as_condition
      acts_as :condition, class_name: Course::Condition.name

      include ConditionInstanceMethods
      extend ConditionClassMethods
    end
  end

  module ConditionalInstanceMethods
    def specific_conditions
      conditions.map(&:actable)
    end

    # Check if all conditions are satisfied by the user.
    #
    # @param [CourseUser] course_user The user that conditions are being checked on
    # @return [Boolean] true if all conditions are met and false otherwise
    def conditions_satisfied_by?(course_user)
      conditions.all? { |condition| condition.satisfied_by?(course_user) }
    end
  end

  module ConditionInstanceMethods
    extend ActiveSupport::Concern

    included do
      after_save :on_condition_change, if: :changed?
    end

    # A human-readable name for each condition; usually just wraps a title
    # or name field. Meant to be used in a polymorphic manner for views.
    def title
      raise NotImplementedError
    end

    # @return [Object] Conditional object that the condition depends on to check if it is
    #   satisfiable
    def dependent_object
      raise NotImplementedError
    end

    # Checks if the condition is satisfied by the user.
    #
    # @param [CourseUser] _user The user that the condition is being checked on
    # @return [Boolean] true if the condition is met and false otherwise
    def satisfied_by?(_user)
      raise NotImplementedError
    end

    private

    def on_condition_change
      execute_after_commit { rebuild_satisfiability_graph(course) }
    end

    # Rebuild the satisfiability graph for the given course.
    #
    # @param [Course] course The course with the dependency graph to be built.
    def rebuild_satisfiability_graph(_course)
      # TODO: Replace with the job for building the satisfiability graph
    end
  end

  module ConditionClassMethods
    # Class that the condition depends on.
    def dependent_class
      raise NotImplementedError
    end

    # Evaluate and update the satisfied conditionals for the given course user.
    #
    # @param [CourseUser] course_user The user with conditionals to be evaluated
    # @return [Course::Conditional::ConditionalSatisfiabilityEvaluationJob] The job instance
    def evaluate_conditional_for(course_user)
      Course::Conditional::ConditionalSatisfiabilityEvaluationJob.perform_later(course_user)
    end
  end
end
