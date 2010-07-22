#!/usr/bin/ruby

require 'rubygems'
require 'gdata4ruby'
$:.unshift 'lib' #use local version, not gem
require 'gcal4ruby'

include GCal4Ruby

@service = Service.new
@username = nil
@password = nil

def tester
  if ARGV.include?("-d")
      @service.debug = true
  end
  ARGV.each do |ar|
    if ar.match("username=")
      @username = ar.gsub("username=", "")
    end
    if ar.match("password=")
      @password = ar.gsub("password=", "")
    end
  end
  service_test
  calendar_test
  event_test
  event_recurrence_test
  event_rrule_parser_test

  render_results
end

def service_test
  puts "---Starting Service Test---"
  puts "1. Authenticate"
  if @service.authenticate(@username, @password)
    successful
  else
    failed
  end
  
  puts "2. Calendar List"
  cals = @service.calendars
  if cals
    successful "Calendars for this Account:"
    cals.each do |cal|
      puts cal.title
    end
  else
    failed
  end
end

def calendar_test
  puts "---Starting Calendar Test---"
  
  puts "1. Create Calendar"
  cal = Calendar.new(@service)
  cal.title = "test calendar"+Time.now.to_s
  puts "Calender exists = "+cal.exists?.to_s
  if cal.save
    successful cal.to_xml
  else
    failed
  end
  
  puts "2. Edit Calendar"
  cal.title = "renamed title"
  if cal.save
    successful cal.to_xml
  else
    puts "Test 2 Failed"
  end
  
  puts "3. Find Calendar by ID"
  c = Calendar.find(@service, {:id => cal.id})
  if c.title == cal.title
    successful
  else
    failed "#{c.title} not equal to #{cal.title}"
  end
  
  puts "4. Delete Calendar"
  if cal.delete and not cal.exists?
    successful
  else
    failed
  end
end

def event_test
  puts "---Starting Event Test---"
  
  puts "1. Create Event"
  event = Event.new(@service)
  event.calendar = @service.calendars[0]
  event.title = "Test Event"
  event.content = "Test event content"
  event.start_time = Time.now+1800
  event.end_time = Time.now+5400
  if event.save
    successful event.to_xml
  else
    failed
  end
  
  puts "2. Edit Event"
  event.title = "Edited title"
  if event.save
    successful event.to_xml
  else
    failed
  end
  
  puts "3. Reload Event"
  if event.reload
    successful
  end
  
  puts "4. Find Event by id"
  e = Event.find(@service, {:id => event.id})
  if e.title == event.title
    successful
  else
    failed "Found event doesn't match existing event"
  end
  
  puts "5. Delete Event"
  if event.delete
    successful 
  else
    failed
  end
end

def event_recurrence_test
  puts "---Starting Event Recurrence Test---"
  
  @first_start = Time.now
  @first_end = Time.now+3600
  @first_freq = {'weekly' => ['TU']}
  @second_start = Time.now+86000
  @second_end = Time.now+89600
  @second_freq = {'weekly' => ['SA']}
  
  puts "1. Create Recurring Event"
  event = Event.new(@service)
  event.calendar = @service.calendars[0]
  event.title = "Test Recurring Event"
  event.content = "Test event content"
  event.recurrence = Recurrence.new({:start_time => @first_start, :end_time => @first_end, :frequency => @first_freq})
  if event.save 
    successful event.to_xml
  else
    failed("recurrence = "+event.recurrence.to_s)
  end
  
  puts "2. Edit Recurrence"
  event.title = "Edited recurring title"
  event.recurrence = Recurrence.new({:start_time => @second_start, :end_time => @second_end, :frequency => @second_freq})
  if event.save 
    successful event.to_xml
  else
    failed
  end
  
  puts "3. Delete Event"
  if event.delete
    successful 
  else
    failed
  end
end

def event_rrule_parser_test
  puts "---Starting Event Recurrence Parser Test---"

  # this is similar to a recurrence created by GCal4Ruby, times should be in UTC (because of the 'Z' at the end)
  basic_rrule = "DTSTART:20100722T134909Z\nDTEND:20100722T144909Z\nRRULE:FREQ=WEEKLY;BYDAY=SA;\n"

  puts "\n1. Parse basic RRULE"
  basic = Recurrence.new(basic_rrule)
  assert_equal 13, basic.start_time.utc.hour, "times should be in UTC"
  assert_equal 49, basic.start_time.min
  assert_equal 14, basic.end_time.utc.hour, "times should be in UTC"
  assert_equal "UTC", basic.start_time.zone
  assert_equal "UTC", basic.end_time.zone
  assert basic.frequency.has_key?('Weekly')
  assert_equal ['SA'], basic.frequency['Weekly']

  # this is similar to one created by Google Calendar, including explicit TimeZone and time standard info
  advanced_rrule = "DTSTART;TZID=America/Argentina/Buenos_Aires:20100722T190000\nDTEND;TZID=America/Argentina/Buenos_Aires:20100722T200000\nRRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;WKST=SU\nBEGIN:VTIMEZONE\nTZID:America/Argentina/Buenos_Aires\nX-LIC-LOCATION:America/Argentina/Buenos_Aires\nBEGIN:STANDARD\nTZOFFSETFROM:-0300\nTZOFFSETTO:-0300\nTZNAME:ART\nDTSTART:19700101T000000\nEND:STANDARD\nEND:VTIMEZONE\n"

  puts "\n2. Parse advanced RRULE"
  advanced = Recurrence.new(advanced_rrule)
  assert_equal 22, advanced.start_time.utc.hour
  assert_equal 0, advanced.start_time.min
  assert_equal 20, advanced.end_time && advanced.end_time.hour
  assert advanced.frequency.has_key?('Weekly')
  assert_equal %w(MO TU WE TH FR), advanced.frequency['Weekly']

  # this one is has a complex RRULE which has interval and until
  # and uses a different, more complex timezone just in case
  complex_rrule = "DTSTART;TZID=Europe/Oslo:20100721T230000\nDTEND;TZID=Europe/Oslo:20100722T000000\nRRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=WE;UNTIL=20100929T210000Z;WKST=SU\nBEGIN:VTIMEZONE\nTZID:Europe/Oslo\nX-LIC-LOCATION:Europe/Oslo\nBEGIN:DAYLIGHT\nTZOFFSETFROM:+0100\nTZOFFSETTO:+0200\nTZNAME:CEST\nDTSTART:19700329T020000\nRRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\nEND:DAYLIGHT\nBEGIN:STANDARD\nTZOFFSETFROM:+0200\nTZOFFSETTO:+0100\nTZNAME:CET\nDTSTART:19701025T030000\nRRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\nEND:STANDARD\nEND:VTIMEZONE"

  puts "\n2. Parse complex RRULE"
  complex = Recurrence.new(complex_rrule)
  assert_equal 21, complex.start_time.utc.hour
  assert_equal 0, complex.start_time.min
  assert_equal 22, complex.end_time && complex.end_time.utc.hour
  assert complex.frequency.has_key?('Weekly')
  assert_equal %w(WE), complex.frequency['Weekly']
  assert complex.frequency.has_key?('interval')
  assert_equal 2, complex.frequency['interval']
end

def assert_equal(expected, received, msg = nil)
  assert(expected == received, [msg, "expected #{expected.inspect} but got #{received.inspect}"].compact * '; ', 1)
end

def assert(condition, msg = nil, depth = 0)
  if condition
    print '.'
    @success_count ||= 0
    @success_count += 1
  else
    print 'F'
    fails << "#{msg || 'Fail'} on #{caller[depth]}"
  end
rescue
  print 'E'
  errors << "#{msg || 'Fail'}; #{$!} // #{$@[0]} on #{caller[depth]}"
end

def failed(m = nil)
  puts "Test Failed"
  puts m if m
  exit()
end

def successful(m = nil)
  puts "Test Successful"
  puts m if m
end

def render_results
  total = @success_count + fails.size + errors.size
  puts "\n# #{total} assertions. Results: #{@success_count} OK, #{fails.size} failures, #{errors.size} errors"
  unless fails.empty?
    puts "## Failures"
    fails.each do |fail|
      puts " * #{fail}"
    end
  end
  unless errors.empty?
    puts "## Errors"
    errors.each do |error|
      puts " * #{error}"
    end
  end
  puts "# #{total} assertions. Results: #{@success_count} OK, #{fails.size} failures, #{errors.size} errors"
end

def errors
  @errors ||= []
end

def fails
  @fails ||= []
end

tester
