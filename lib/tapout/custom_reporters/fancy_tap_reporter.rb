class FancyTapReporter < Tapout::Reporters::Abstract

  #
  def start_suite(entry)
    @start = Time.now
    @i = 0
    #n = 0
    #suite.concerns.each{ |f| f.concerns.each { |s| n += s.ok.size } }
    puts "1..#{entry['count']}"
  end

  #
  def start_case(entry)
    #$stdout.puts concern.label.ansi(:bold)
  end

  #
  def pass(entry)
    super(entry)

    @i += 1
    #desc = entry['message'] #+ " #{ok.arguments.inspect}"

    puts "ok".ansi(*config.pass) + highlight(" #{@i} - #{entry['label']}")
  end

  #
  def fail(entry)
    super(entry)

    @i += 1
    x = entry['exception']

    #desc = #ok.concern.label + " #{ok.arguments.inspect}"

    body = []
    body << "FAIL #{x['file']}:#{x['line']}" #clean_backtrace(exception.backtrace)[0]
    body << "#{x['message']}"
    body << x['snippet']
    body << x['backtrace']
    body << entry['stdout']
    body = body.join("\n").gsub(/^/, '  # ')

    puts "not ok".ansi(*config.fail) + highlight(" #{@i} - #{entry['label']}")
    puts body
  end

  #
  def error(entry)
    super(entry)

    @i += 1
    x = entry['exception']

    #desc = ok.concern.label + " #{ok.arguments.inspect}"

    body = []
    body << "ERROR #{x['file']}:#{x['line']}" #clean_backtrace(exception.backtrace)[0..2].join("    \n")
    body << "#{x['class']}: #{x['message']}"
    body << ""
    body << x['backtrace']
    body << entry['stdout']
    body = body.join("\n").gsub(/^/, '  # ')

    puts "not ok".ansi(*config.error) + highlight(" #{@i} - #{entry['label']}")
    puts body
  end

  def todo(entry)
    super(entry)
    @i += 1
    puts 'ok'.ansi(*config.pass) + highlight(" #{@i} - #{entry['label']} # skip #{entry['exception']['message']}")
    puts "  # #{entry['exception']['message']}"
  end

  def highlight(anything)
    anything.ansi(*config.highlight)
  end

  # to print out formatted time and rates
  def finish_suite(entry)
    time, rate, avg = time_tally(entry)
    delta = duration(time)

    ending = []
    ending << ""
    ending << tally_message(entry)
    ending << "[%s %.2ft/s %.4fs/t] " % [delta, rate, avg] + "Finished at: #{Time.now}"
    ending = ending.join("\n").gsub(/^/, '  # ')

    puts ending
  end

end