require 'minitap'

module Minitest

  ##
  # Base class for TapY and TapJ runners.
  #
  class Minitap

    def tapout_before_case(test_case)
      doc = {
          'type'    => 'case',
          'subtype' => '',
          'label'   => "#{test_case}",
          'level'   => 0
      }
      return doc
    end

  end

end
