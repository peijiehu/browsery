
module Browsery
  module Utils

    # Module that injects a convenience method to access the logger.
    module Loggable

      # Convenience instance method to access the default logger.
      def logger
        Browsery.logger
      end

    end

  end
end
