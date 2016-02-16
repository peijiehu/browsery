
module Browsery
  module Utils

    # Useful helpers to generate fake data.
    module DataGeneratorHelper

      # All valid area codes in the US
      NPA = ["201", "202", "203", "205", "206", "207", "208", "209", "210", "212", "213", "214", "215", "216", "217", "218", "219", "224", "225", "227", "228", "229", "231", "234", "239", "240", "248", "251", "252", "253", "254", "256", "260", "262", "267", "269", "270", "276", "281", "283", "301", "302", "303", "304", "305", "307", "308", "309", "310", "312", "313", "314", "315", "316", "317", "318", "319", "320", "321", "323", "330", "331", "334", "336", "337", "339", "347", "351", "352", "360", "361", "386", "401", "402", "404", "405", "406", "407", "408", "409", "410", "412", "413", "414", "415", "417", "419", "423", "424", "425", "434", "435", "440", "443", "445", "464", "469", "470", "475", "478", "479", "480", "484", "501", "502", "503", "504", "505", "507", "508", "509", "510", "512", "513", "515", "516", "517", "518", "520", "530", "540", "541", "551", "557", "559", "561", "562", "563", "564", "567", "570", "571", "573", "574", "580", "585", "586", "601", "602", "603", "605", "606", "607", "608", "609", "610", "612", "614", "615", "616", "617", "618", "619", "620", "623", "626", "630", "631", "636", "641", "646", "650", "651", "660", "661", "662", "667", "678", "682", "701", "702", "703", "704", "706", "707", "708", "712", "713", "714", "715", "716", "717", "718", "719", "720", "724", "727", "731", "732", "734", "737", "740", "754", "757", "760", "763", "765", "770", "772", "773", "774", "775", "781", "785", "786", "801", "802", "803", "804", "805", "806", "808", "810", "812", "813", "814", "815", "816", "817", "818", "828", "830", "831", "832", "835", "843", "845", "847", "848", "850", "856", "857", "858", "859", "860", "862", "863", "864", "865", "870", "872", "878", "901", "903", "904", "906", "907", "908", "909", "910", "912", "913", "914", "915", "916", "917", "918", "919", "920", "925", "928", "931", "936", "937", "940", "941", "947", "949", "952", "954", "956", "959", "970", "971", "972", "973", "975", "978", "979", "980", "984", "985", "989"]

      # Easier to assume for now a list of valid exchanges
      NXX = NPA

      # Generate a string of random digits.
      #
      # @param digits [Fixnum] the number of digits in the string
      # @return [String] the string of digits
      def generate_digits(digits = 1)
        Faker::Number.number(digits)
      end

      # Generate a random email address.
      #
      # The specifier portion may be:
      #
      # * `nil`, in which case nothing special happens;
      # * a `String`, in which case the words in the string is shuffled, and
      #   random separators (`.` or `_`) are inserted between them;
      # * an `Integer`, in which case a random alpha-string will be created
      #   with length of at least that many characters;
      # * a `Range`, in which case a random alpha-string of length within the
      #   range will be produced.
      #
      # @param specifier [nil, String, Integer, Range] a specifier to help
      #   generate the username part of the email address
      # @return [String]
      def generate_email(specifier = nil)
        Faker::Internet.email(name)
      end

      # Generate a handsome first name.
      #
      # @param length [#to_i, nil]
      # @return [String]
      def generate_first_name(length = nil)
        first_name = ''
        if length.nil?
          first_name = Faker::Name.first_name
        else
          # Ensure a name with requested length is generated
          name_length = Faker::Name.first_name.length
          if length > name_length
            first_name = Faker::Lorem.characters(length)
          else
            first_name = Faker::Name.first_name[0..length.to_i]
          end
        end
        # remove all special characters since name fields on our site have this requirement
        first_name.gsub!(/[^0-9A-Za-z]/, '')
        first_name
      end

      # Generate a gosh-darn awesome last name.
      #
      # @param length [#to_i, nil]
      # @return [String]
      def generate_last_name(length = nil)
        last_name = ''
        if length.nil?
          last_name = Faker::Name.last_name
        else
          # Ensure a name with requested length is generated
          name_length = Faker::Name.last_name.length
          if length > name_length
            last_name = Faker::Lorem.characters(length)
          else
            last_name = Faker::Name.last_name[0..length.to_i]
          end
        end
        # remove all special characters since name fields on our site have this requirement
        last_name.gsub!(/[^0-9A-Za-z]/, '')
        last_name
      end

      # Generate a unique random email ends with @test.com
      def generate_test_email
        [ "#{generate_last_name}.#{generate_unique_id}", 'test.com' ].join('@')
      end

      # Generate a random number between 0 and `max - 1` if `max` is >= 1,
      # or between 0 and 1 otherwise.
      def generate_number(max = nil)
        rand(max)
      end

      # Generates a U.S. phone number (NANPA-aware).
      #
      # @param format [Symbol, nil] the format of the phone, one of: nil,
      #   `:paren`, `:dotted`, or `:dashed`
      # @return [String] the phone number
      def generate_phone_number(format = nil)
        case format
        when :paren, :parenthesis, :parentheses
          '(' + NPA.sample + ') ' + NXX.sample + '-' + generate_digits(4)
        when :dot, :dotted, :dots, :period, :periods
          [ NPA.sample, NXX.sample, generate_digits(4) ].join('.')
        when :dash, :dashed, :dashes
          [ NPA.sample, NXX.sample, generate_digits(4) ].join('-')
        else
          NPA.sample + NXX.sample + generate_digits(4)
        end
      end

      # Generate a random date.
      #
      # @param start_date [Integer] minimum date range
      # @param end_date [Integer] maximum date range
      # @return [String] the generated date
      def generate_date(start_date, end_date)
        random_date = rand start_date..end_date
        return random_date.to_formatted_s(:month_day_year)
      end
      
      # Generate a unique id with a random hex string and time stamp string
      def generate_unique_id
        SecureRandom.hex(3) + Time.current.to_i.to_s
      end

      # Generate a random password of a certain length, or default length 12
      #
      # @param length [#to_i, nil]
      # @return [String]
      def generate_password(length = nil)
        if length.nil?
          SecureRandom.hex(6) # result length = 12
        else
          chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
          (1..length).collect{|a| chars[rand(chars.length)] }.join
        end
      end

    end

  end
end
