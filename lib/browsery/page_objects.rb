module Browsery

  # This is the overarching module that contains page objects, modules, and
  # widgets.
  #
  # When new modules or classes are added, an `autoload` clause must be added
  # into this module so that requires are taken care of automatically.
  module PageObjects

    # Exception to capture validation problems when instantiating a new page
    # object. The message contains the page object being instantiated as well
    # as the original, underlying error message if any.
    class InvalidePageState < Exception; end

  end

end

# Major classes and modules
require_relative 'page_objects/element_container'
require_relative 'page_objects/base'
require_relative 'page_objects/section'
require_relative 'page_objects/overlay/base'
require_relative 'page_objects/widgets/base'
