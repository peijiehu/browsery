module Browsery
  class Parallel

    attr_reader :all_tests, :simultaneous_jobs

    def initialize(simultaneous_jobs, all_tests)
      @start_time = Time.now

      @result_dir = 'logs/tap_results'

      connector = Browsery.settings.connector
      @on_sauce = true if connector.include? 'saucelabs'
      @platform = connector.split(':')[2] || ''

      @simultaneous_jobs = simultaneous_jobs
      @simultaneous_jobs = 10 if run_on_mac? # saucelabs account limit for parallel is 10 for mac
      @all_tests = all_tests

      @pids = []
      @static_run_command = "browsery -c #{Browsery.settings.connector} -e #{Browsery.settings.env}"
      if Browsery.settings.rerun_failure
        @static_run_command += " -R #{Browsery.settings.rerun_failure}"
      end
      tap_reporter_path = Browsery.gem_root.join('lib/tapout/custom_reporters/fancy_tap_reporter.rb')
      @pipe_tap = "--tapy | tapout --no-color -r #{tap_reporter_path.to_s} fancytap"
    end

    # return true only if specified to run on mac in connector
    # @return [boolean]
    def run_on_mac?
      @platform.include?('osx')
    end

    # remove all results files under @result_dir if there's any
    def clean_result!
      raise Exception, '@result_dir is not set' if @result_dir.nil?
      unless Dir.glob("#{@result_dir}/*").empty?
        FileUtils.rm_rf(Dir.glob("#{@result_dir}/*"))
      end
      puts "Cleaning result files.\n"
    end

    def remove_redundant_tap
      ever_failed_tests_file = "#{@result_dir}/ever_failed_tests.json"
      if File.file? ever_failed_tests_file
        data_hash = JSON.parse(File.read(ever_failed_tests_file))
        data_hash.keys.each do |test|
          if test.start_with? 'test_'
            tap_result_file = "#{@result_dir}/#{test}.t"
            result_lines = IO.readlines(tap_result_file)
            last_tap_start_index = 0
            last_tap_end_index = result_lines.size - 1
            result_lines.each_with_index do |l, index|
              last_tap_start_index = index if l.delete!("\n") == '1..1'
            end
            File.open(tap_result_file, 'w') do |f|
              f.puts result_lines[last_tap_start_index..last_tap_end_index]
            end
            puts "Processed #{tap_result_file}"
          else
            next
          end
        end
      else
        puts "==> File #{ever_failed_tests_file} doesn't exist - all tests passed!"
      end
    end

    # Aggregate all individual test_*.t files
    # replace them with one file - test_aggregated_result.tap
    # so they will be considered as one test plan by tap result parser
    def aggregate_tap_results
      results_count = Dir.glob("#{@result_dir}/*.t").size
      File.open("#{@result_dir}/test_aggregated_result.tap", 'a+') do |result_file|
        result_stats = {
            'pass' => 0,
            'fail' => 0,
            'errs' => 0,
            'todo' => 0,
            'omit' => 0
        }
        result_stats_line_start = '  # 1 tests:'
        result_file.puts "1..#{results_count}"
        file_count = 0
        Dir.glob("#{@result_dir}/*.t") do |filename|
          file_count += 1
          File.open(filename, 'r') do |file|
            breakpoint_line = 0
            file.each_with_index do |line, index|
              next if index == 0 || (breakpoint_line > 0 && index > breakpoint_line)
              if line.start_with?(result_stats_line_start)
                pass, fail, errs, todo, omit = line.match(/(\d+) pass, (\d+) fail, (\d+) errs, (\d+) todo, (\d+) omit/).captures
                one_test_result = {
                    'pass' => pass.to_i,
                    'fail' => fail.to_i,
                    'errs' => errs.to_i,
                    'todo' => todo.to_i,
                    'omit' => omit.to_i
                }
                result_stats = result_stats.merge(one_test_result) { |k, total, one| total + one }
                breakpoint_line = index
              elsif line.strip == '#'
                next
              else
                if line.start_with?('ok 1') || line.start_with?('not ok 1')
                  line_begin, line_end = line.split('1 -')
                  result_file.puts [line_begin, line_end].join("#{file_count} -")
                else
                  result_file.puts line
                end
              end
            end
          end
          File.delete(filename)
        end
        result_file.puts '  #'
        result_file.puts "  # #{results_count} tests: #{result_stats['pass']} pass, #{result_stats['fail']} fail, #{result_stats['errs']} errs, #{result_stats['todo']} todo, #{result_stats['omit']} omit"
        result_file.puts "  # [00:00:00.00 0.00t/s 00.0000s/t] Finished at: #{Time.now}"
      end
    end

    def count_browsery_process
      counting_process_output = IO.popen "ps -ef | grep 'bin/#{@static_run_command}' -c"
      counting_process_output.readlines[0].to_i - 1 # minus grep process
    end

    # run multiple commands with logging to start multiple tests in parallel
    # @param [Integer, Array]
    # n = number of tests will be running in parallel
    def run_in_parallel!
      size = all_tests.size
      if size <= simultaneous_jobs
        run_test_set(all_tests)
        puts "CAUTION! All #{size} tests are starting at the same time!"
        puts "will not really run it since computer will die" if size > 30
        sleep 20
      else
        first_test_set = all_tests[0, simultaneous_jobs]
        all_to_run = all_tests[simultaneous_jobs..(all_tests.size - 1)]
        run_test_set(first_test_set)
        keep_running_full(all_to_run)
      end

      Process.waitall
      puts "\nAll Complete! Started at #{@start_time} and finished at #{Time.now}\n"
    end

    # runs each test from a test set in a separate child process
    def run_test_set(test_set)
      test_set.each do |test|
        run_command = "#{@static_run_command} -n #{test} #{@pipe_tap} > #{@result_dir}/#{test}.t"
        pipe = IO.popen(run_command)
        puts "Running #{test}  #{pipe.pid}"
      end
    end

    # recursively keep running #{simultaneous_jobs} number of tests in parallel
    # exit when no test left to run
    def keep_running_full(all_to_run)
      running_subprocess_count = count_browsery_process - 1 # minus parent process
      puts "WARNING: running_subprocess_count = #{running_subprocess_count}
            is more than what it is supposed to run(#{simultaneous_jobs}),
            notify browsery maintainers" if running_subprocess_count > simultaneous_jobs + 1
      while running_subprocess_count >= simultaneous_jobs
        sleep 5
        running_subprocess_count = count_browsery_process - 1
      end
      to_run_count = simultaneous_jobs - running_subprocess_count
      tests_to_run = all_to_run.slice!(0, to_run_count)

      run_test_set(tests_to_run)

      keep_running_full(all_to_run) if all_to_run.size > 0
    end

    # @deprecated Use more native wait/check of Process
    def wait_for_pids(pids)
      running_pids = pids # assume all pids are running at this moment
      while running_pids.size > 1
        sleep 5
        puts "running_pids = #{running_pids}"
        running_pids.each do |pid|
          unless process_running?(pid)
            puts "#{pid} is not running, removing it from pool"
            running_pids.delete(pid)
          end
        end
      end
    end

    # @deprecated Too time consuming and fragile, should use more native wait/check of Process
    def wait_all_done_saucelabs
      size = all_tests.size
      job_statuses = saucelabs_last_n_statuses(size)
      while job_statuses.include?('in progress')
        puts "There are tests still running, waiting..."
        sleep 20
        job_statuses = saucelabs_last_n_statuses(size)
      end
    end

    private

    # call saucelabs REST API to get last #{limit} jobs' statuses
    # possible job status: complete, error, in progress
    def saucelabs_last_n_statuses(limit)
      username = Browsery.settings.sauce_username
      access_key = Browsery.settings.sauce_access_key

      # call api to get most recent #{limit} jobs' ids
      http_auth = "https://#{username}:#{access_key}@saucelabs.com/rest/v1/#{username}/jobs?limit=#{limit}"
      response = get_response_with_retry(http_auth) # response was originally an array of hashs, but RestClient converts it to a string
      # convert response back to array
      response[0] = ''
      response[response.length-1] = ''
      array_of_hash = response.split(',')
      id_array = Array.new
      array_of_hash.each do |hash|
        hash = hash.gsub(':', '=>')
        hash = eval(hash)
        id_array << hash['id'] # each hash contains key 'id' and value of id
      end

      # call api to get job statuses
      statuses = Array.new
      id_array.each do |id|
        http_auth = "https://#{username}:#{access_key}@saucelabs.com/rest/v1/#{username}/jobs/#{id}"
        response = get_response_with_retry(http_auth)
        begin
          # convert response back to hash
          str = response.gsub(':', '=>')
          # this is a good example why using eval is dangerous, the string has to contain only proper Ruby syntax, here it has 'null' instead of 'nil'
          formatted_str = str.gsub('null', 'nil')
          hash = eval(formatted_str)
          statuses << hash['status']
        rescue SyntaxError
          puts "SyntaxError, response from saucelabs has syntax error"
        end
      end
      return statuses
    end

    def get_response_with_retry(url)
      retries = 5 # number of retries
      begin
        response = RestClient.get(url) # returns a String
      rescue
        puts "Failed at getting response from #{url} via RestClient \n Retrying..."
        retries -= 1
        retry if retries > 0
        response = RestClient.get(url) # retry the last time, fail if it still throws exception
      end
    end

    def process_running?(pid)
      begin
        Process.getpgid(pid)
        true
      rescue Errno::ESRCH
        false
      end
    end

  end
end
