module Browsery
  class Logger < ActiveSupport::Logger

    LOG_FILE_MODE = File::WRONLY | File::APPEND | File::CREAT

    def initialize(file, *args)
      file = File.open(Browsery.root.join('logs', file), LOG_FILE_MODE) unless file.respond_to?(:write)
      super(file, *args)
    end

  end
end
