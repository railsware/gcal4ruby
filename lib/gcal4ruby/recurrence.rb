# Author:: Mike Reich (mike@seabourneconsulting.com)
# Copyright:: Copyright (C) 2010 Mike Reich
# License:: GPL v2
#--
# Licensed under the General Public License (GPL), Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
# Feel free to use and update, but be sure to contribute your
# code back to the project and attribute as required by the license.
#++

class Time
  #Returns a ISO 8601 complete formatted string of the time
  def complete
    self.utc.strftime("%Y%m%dT%H%M%S")
  end
  
  def self.parse_complete(value)
    d, h = value.split("T")
    return Time.parse(d+" "+h.gsub("Z", ""))
  end
end

module GCal4Ruby
  #The Recurrence class stores information on an Event's recurrence.  The class implements
  #the RFC 2445 iCalendar recurrence description.
  class Recurrence
    #The event start date/time
    attr_reader :start_time
    #The event end date/time
    attr_reader :end_time
    #the event reference
    attr_reader :event
    #The date until which the event will be repeated
    attr_reader :repeat_until
    #The event frequency
    attr_reader :frequency
    #True if the event is all day (i.e. no start/end time)
    attr_accessor :all_day
    
    #Accepts an optional attributes hash or a string containing a properly formatted ISO 8601 recurrence rule.  Returns a new Recurrence object
    def initialize(vars = {})
      if vars.is_a? Hash
        vars.each do |key, value|
          self.send("#{key}=", value)
        end
      elsif vars.is_a? String
        self.load(vars)
      end
      @all_day ||= false
    end
    
    #Accepts a string containing a properly formatted ISO 8601 recurrence rule and loads it into the recurrence object
    def load(rec)
      attrs = rec.split("\n")
      attrs.each do |val|
        key, value = val.split(":")
        case key
          when 'DTSTART'
            @start_time = Time.parse_complete(value)
          when 'DTSTART;VALUE=DATE'
            @start_time = Time.parse(value)
            @all_day = true
          when 'DTSTART;VALUE=DATE-TIME'
            @start_time = Time.parse_complete(value)
          when 'DTEND'
            @end_time = Time.parse_complete(value)
          when 'DTEND;VALUE=DATE'
            @end_time = Time.parse(value)
          when 'DTEND;VALUE=DATE-TIME'
            @end_time = Time.parse_complete(value)
          when 'RRULE'
            vals = value.split(";")
            key = ''
            by = ''
            int = nil
            vals.each do |rr|
              a, h = rr.split("=")
              case a 
                when 'FREQ'
                  key = h.downcase.capitalize
                when 'INTERVAL'
                  int = h
                when 'UNTIL'
                  @repeat_until = Time.parse(value)
                else
                  by = h.split(",")
              end
            end
            @frequency = {key => by}
            @frequency.merge({'interval' => int}) if int
        end
      end
    end
    
    def to_s
      output = ''
      if @frequency
        f = ''
        i = ''
        by = ''
        @frequency.each do |key, v|
          if v.is_a?(Array) 
            if v.size > 0
              value = v.join(",") 
            else
              value = nil
            end
          else
            value = v
          end
          f += "#{key.downcase} " if key != 'interval'
          case key.downcase
            when "secondly"
              by += "every #{value} second"
            when "minutely"
              by += "every #{value} minute"
            when "hourly"
              by += "every #{value} hour"
            when "weekly"
              by += "on #{value}" if value
            when "monthly"
              by += "on #{value}"
            when "yearly"
              by += "on the #{value} day of the year"
            when 'interval'
              i += "for #{value} times"
          end
        end
        output += f+i+by
      end      
      if @repeat_until
        output += " and repeats until #{@repeat_until.strftime("%m/%d/%Y")}"
      end
      output
    end
    
    #Returns a string with the correctly formatted ISO 8601 recurrence rule
    def to_recurrence_string
      
      output = ''
      if @all_day
        output += "DTSTART;VALUE=DATE:#{@start_time.utc.strftime("%Y%m%d")}\n"
      else
        output += "DTSTART;VALUE=DATE-TIME:#{@start_time.complete}\n"
      end
      if @all_day
        output += "DTEND;VALUE=DATE:#{@end_time.utc.strftime("%Y%m%d")}\n"
      else
        output += "DTEND;VALUE=DATE-TIME:#{@end_time.complete}\n"
      end
      output += "RRULE:"
      if @frequency
        f = 'FREQ='
        i = ''
        by = ''
        @frequency.each do |key, v|
          if v.is_a?(Array) 
            if v.size > 0
              value = v.join(",") 
            else
              value = nil
            end
          else
            value = v
          end
          f += "#{key.upcase};" if key != 'interval'
          case key.downcase
            when "secondly"
              by += "BYSECOND=#{value};"
            when "minutely"
              by += "BYMINUTE=#{value};"
            when "hourly"
              by += "BYHOUR=#{value};"
            when "weekly"
              by += "BYDAY=#{value};" if value
            when "monthly"
              by += "BYDAY=#{value};"
            when "yearly"
              by += "BYYEARDAY=#{value};"
            when 'interval'
              i += "INTERVAL=#{value};"
          end
        end
        output += f+i+by
      end      
      if @repeat_until
        output += "UNTIL=#{@repeat_until.strftime("%Y%m%d")}"
      end
      
      output += "\n"
    end
    
    #Sets the start date/time.  Must be a Time object.
    def start_time=(s)
      if not s.is_a?(Time)
        raise RecurrenceValueError, "Start must be a date or a time"
      else
        @start_time = s
      end
    end
    
    #Sets the end Date/Time. Must be a Time object.
    def end_time=(e)
      if not e.is_a?(Time)
        raise RecurrenceValueError, "End must be a date or a time"
      else
        @end_time = e
      end
    end
    
    #Sets the parent event reference
    def event=(e)
      if not e.is_a?(Event)
        raise RecurrenceValueError, "Event must be an event"
      else
        @event = e
      end
    end
    
    #Sets the end date for the recurrence
    def repeat_until=(r)
      if not  r.is_a?(Date)
        raise RecurrenceValueError, "Repeat_until must be a date"
      else
        @repeat_until = r
      end
    end
    
    #Sets the frequency of the recurrence.  Should be a hash with one of 
    #"SECONDLY", "MINUTELY", "HOURLY", "DAILY", "WEEKLY", "MONTHLY", "YEARLY" as the key,
    #and as the value, an array containing zero to n of the following:
    #- *Secondly*: A value between 0 and 59.  Causes the event to repeat on that second of each minut.
    #- *Minutely*: A value between 0 and 59.  Causes the event to repeat on that minute of every hour.
    #- *Hourly*: A value between 0 and 23.  Causes the even to repeat on that hour of every day.
    #- *Daily*: No value needed - will cause the event to repeat every day until the repeat_until date.
    #- *Weekly*: A value of the first two letters of a day of the week.  Causes the event to repeat on that day.
    #- *Monthly*: A value of a positive or negative integer (i.e. +1) prepended to a day-of-week string ('TU') to indicate the position of the day within the month.  E.g. +1TU would be the first tuesday of the month.
    #- *Yearly*: A value of 1 to 366 indicating the day of the year.  May be negative to indicate counting down from the last day of the year.
    #
    #Optionally, you may specific a second hash pair to set the interval the event repeats:
    #   "interval" => '2'
    #If the interval is missing, it is assumed to be 1.
    #
    #===Examples
    #Repeat event every Tuesday:
    #   frequency = {"Weekly" => ["TU"]}
    #
    #Repeat every first and third Monday of the month
    #   frequency = {"Monthly" => ["+1MO", "+3MO"]}
    #
    #Repeat on the last day of every year
    #   frequency = {"Yearly" => [366]}
    #
    #Repeat every other week on Friday
    #   frequency = {"Weekly" => ["FR"], "interval" => "2"}
    
    def frequency=(f)
      if f.is_a?(Hash)
        @frequency = f
      else
        raise RecurrenceValueError, "Frequency must be a hash (see documentation)"
      end
    end
  end
end