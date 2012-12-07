#!/usr/bin/ruby
# The program takes an initial word or phrase from
#
# Author::    David Barbion  (dbarbion@gmail.com)
# License::   Distributes under the same terms as Ruby
#

# Default history file
DEF_HISTORY_FILE="/tmp/.cpu_time_totaller.log"

require 'etc'
require 'optparse'

# This class computes the total running time of user's processes.
# This is done by saving, in a history file, total CPUTIME per user.
# This value (per user) is substracted from current values, giving the CPUTIME between two run
# An average value is computed, giving the percentage of CPU used by a user
# The same is done for the time user's processes wait for IO to complete (IOWAIT)
class Totaltime

    def initialize(aggregate=true)
        @histoprocstat   = Hash.new # historical cputime
        @histoprociowait = Hash.new # historical iowait
        @currprocstat    = Hash.new # current cputime
        @currprociowait  = Hash.new # current iowait
        @cpuusage    = Hash.new 
        @iowaitusage = Hash.new
        @histodate = 0 # date/time of last run
        @rundate   = 0 # now

        @rundate = Time.now()
        @rundate = @rundate.strftime("%s").to_i

        number_of_cpu = self.get_number_of_cpu()
        # Retrieve data of last run
        self.load_history
        # Get current cputime/iowait
        self.get_process_stat
        # Compute average cpu / iowait 
        @cpuusage    = self.get_mean_cpu_usage(@currprocstat,@histoprocstat)
        @iowaitusage = self.get_mean_iowait_usage(@currprociowait,@histoprociowait)
        if (!aggregate) 
            @cpuusage.each_key do |username|
                @cpuusage[username]    = @cpuusage[username] / number_of_cpu
                @iowaitusage[username] = @iowaitusage[username] / number_of_cpu
            end
        end
        # Save current usage to history file
        self.save_history
    end

    # 
    def get_cpu_usage
        return(@cpuusage)
    end

    # Get cpu usage for a specified user
    def get_cpu_usage_for_user(username)
        return(@cpuusage[username])
    end

    # Get iowait for a specified user
    def get_iowait_usage_for_user(username)
        return(@iowaitusage[username])
    end

    # Returns a table containing all PID in the system
    def get_all_pid
        all_pid = Array.new
        Dir.foreach("/proc") do |pid|
           if (File.exists?("/proc/#{pid}/status"))
               all_pid.push(pid)
           end
        end
        return(all_pid)
    end

    # Get all process stat (CPUTIME and IOWAIT)
    def get_process_stat
       self.get_all_pid.each do |pid|
           uid = self.get_uid_of_pid(pid)
           username = Etc::getpwuid(uid).name

           statline = IO.read("/proc/#{pid}/stat")
           stat = statline.split(' ')
           #time = stat[13].to_i+stat[14].to_i+stat[15].to_i+stat[16].to_i
           time = stat[13].to_i+stat[14].to_i
           if (!@currprocstat.has_key?(username))
               @currprocstat[username] = 0
           end
           @currprocstat[username] = @currprocstat[username] + time 

           iowait = stat[41].to_i
           if (!@currprociowait.has_key?(username))
               @currprociowait[username] = 0
           end
           @currprociowait[username] += iowait
        end
    end

    # Takes two hash in input
    # substract 2nd to 1st
    # and returns the delta
    def get_data_delta(current,history)
        deltatime = Hash.new
        current.each do |username,value|
            if (history.has_key?(username) && !history[username].nil?)
                if (!value.nil? && value >= history[username])
                    deltatime[username] = value - history[username]
                else
                    deltatime[username] = 0
                end
            else
                deltatime[username] = 0
            end
        end         
        return(deltatime)
    end

    def get_time_delta
        return(@rundate - @histodate)
    end

    def get_mean_cpu_usage(current,history)
        cpuusage = Hash.new
        self.get_data_delta(current,history).each do |username,usedtime|
            # this is to avoid division by 0
            if (self.get_time_delta)
                cpuusage[username] = usedtime.to_i / self.get_time_delta 
            else
                cpuusage[username] = 0
            end
        end      
        return(cpuusage)
    end

    def get_mean_iowait_usage(current,history)
        iowaitusage = Hash.new
        self.get_data_delta(current,history).each do |username,usedtime|
            # this is to avoid division by 0
            if (self.get_time_delta)
                iowaitusage[username] = usedtime.to_i / self.get_time_delta 
            else
                iowaitusage[username] = 0
            end
        end      
        return(iowaitusage)
    end
    def save_history(file=DEF_HISTORY_FILE)
        begin
            f = File.new(file, File::CREAT|File::TRUNC|File::RDWR, 0644)
            f.puts(@rundate)
            @currprocstat.each do |username,time|
                f.puts("#{username} #{time} #{@currprociowait[username]}")
            end
            f.close
        rescue => e
            puts "Cannot save history data: #{e}"
        end
    end


    def load_history(file=DEF_HISTORY_FILE)
        begin
            f = File.open(file)
            @histodate = f.gets.to_i
            while (line = f.gets)
                line =~ /(.*) ([0-9]*) ([0-9]*)/
                @histoprocstat[$1]   =  $2.to_i
                @histoprociowait[$1] = $3.to_i
            end
            f.close
        rescue => e
            puts "Cannot get history data: #{e}"
        end
    end

    # Get the owner's UID of a specified PID
    def get_uid_of_pid(pid)
        IO.foreach("/proc/#{pid}/status") do |line|
            case line
                when /Uid:\s*?(\d+)\s*?(\d+)/
                    return($1.to_i)
            end
        end
    end

    # Get the owner's EUID of a specified PID
    def get_euid_of_pid(pid)
        IO.foreach("/proc/#{pid}/status") do |line|
            case line
                when /Uid:\s*?(\d+)\s*?(\d+)/
                    return($2.to_i)
            end
        end
    end

    # Get the number of CPU installed in the system
    def get_number_of_cpu
        return `cat /proc/cpuinfo | grep processor | wc -l`.to_i
    end
end

def output_help
    puts "Usage: #{File.basename(__FILE__)} [ --help ] [ -a ]"
    puts "  -a        Aggregate CPU usage, having percentage for one processor (for 4 CPU, max will be 400%)"
    puts "            Default is to compute percentage over all processors"
end

aggregate_cpu=false
# Parse command line options
opts = OptionParser.new
opts.on('-h', '--help') { output_help; exit 0 }
opts.on('-a')           { aggregate_cpu=true }
opts.parse!(ARGV) rescue return false

mytotaltime = Totaltime.new(aggregate_cpu)
puts "User            CPU%  IO%"
mytotaltime.get_cpu_usage.each do |username,value|
    puts "#{username.ljust(15)} #{mytotaltime.get_cpu_usage_for_user(username).to_s.rjust(3)}% #{mytotaltime.get_iowait_usage_for_user(username).to_s.rjust(3)}%"
end

