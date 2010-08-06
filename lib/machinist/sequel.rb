require 'machinist'
require 'machinist/blueprints'
require 'sequel'

module Machinist
  class SequelAdapter
    def self.has_association?(object, attribute)
      object.class.associations.include?(attribute)
    end

    def self.class_for_association(object, attribute)
      object.class.association_reflection(attribute).associated_class
    end

    def self.assign_attribute(object, attribute, value)
      if Machinist.nerfed? && has_association?(object, attribute)
        object.associations[attribute] = value
      else
        object.send("#{attribute}=", value)
      end
    end

    def self.assigned_attributes_without_associations(lathe)
      attributes = {}
      lathe.assigned_attributes.each_pair do |attribute, value|
        association = lathe.object.class.association_reflection(attribute)
        if association && association[:type] == :many_to_one
          key = association[:key] || association.default_key
          attributes[key] = value ? value.send(association.primary_key) : nil
        else
          attributes[attribute] = value
        end
      end
      attributes
    end
  end

  module SequelExtensions
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def make(*args, &block)
        lathe = Lathe.run(Machinist::SequelAdapter, self.new, *args)
        unless Machinist.nerfed?
          lathe.object.save(:raise_on_failure => true)
        end
        lathe.object(&block)
      end

      def make_unsaved(*args)
        object = Machinist.with_save_nerfed { make(*args) }
        yield object if block_given?
        object
      end

      def plan(*args)
        lathe = Lathe.run(Machinist::SequelAdapter, self.new, *args)
        Machinist::SequelAdapter.assigned_attributes_without_associations(lathe)
      end      
    end
  end
end

class Sequel::Model
  include Machinist::Blueprints
  include Machinist::SequelExtensions
end
