class IPAddress

  module Lazy

    private

    def lazy(attr, freeze = true)
      class << self; self; end.class_eval { attr_reader attr }

      value =
        instance_variable_get(name = "@#{attr}") ||
        instance_variable_set(name, yield)

      freeze ? value.freeze : value
    end

  end

end
