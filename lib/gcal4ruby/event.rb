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

require 'gcal4ruby/recurrence'

module GCal4Ruby
  #The Event Class represents a remote event in calendar
  #
  #=Usage
  #All usages assume a successfully authenticated Service and valid Calendar.
  #1. Create a new Event
  #    event = Event.new(service, {:calendar => cal, :title => "Soccer Game", :start => Time.parse("12-06-2009 at 12:30 PM"), :end => Time.parse("12-06-2009 at 1:30 PM"), :where => "Merry Playfields"})
  #    event.save
  #
  #2. Find an existing Event by title
  #    event = Event.find(service, {:title => "Soccer Game"})
  #
  #3. Find an existing Event by ID
  #    event = Event.find(service, {:id => event.id})
  #
  #4. Find all events containing the search term
  #    event = Event.find(service, "Soccer Game")
  #
  #5. Find all events on a calendar containing the search term
  #    event = Event.find(service, "Soccer Game", {:calendar => cal.id})
  #
  #6. Find events within a date range
  #    event = Event.find(service, "Soccer Game", {'start-min' => Time.parse("01/01/2010").utc.xmlschema, 'start-max' => Time.parse("06/01/2010").utc.xmlschema})
  #
  #7. Create a recurring event for every saturday
  #    event = Event.new(service)
  #    event.title = "Baseball Game"
  #    event.calendar = cal
  #    event.where = "Municipal Stadium"
  #    event.recurrence = Recurrence.new
  #    event.recurrence.start_time = Time.parse("06/20/2009 at 4:30 PM")
  #    event.recurrence.end_time = Time.parse("06/20/2009 at 6:30 PM")
  #    event.recurrence.frequency = {"weekly" => ["SA"]}
  #    event.save 
  #
  #8. Create an event with a 15 minute email reminder
  #    event = Event.new(service)
  #    event.calendar = cal
  #    event.title = "Dinner with Kate"
  #    event.start_time = Time.parse("06/20/2009 at 5 pm")
  #    event.end_time = Time.parse("06/20/2009 at 8 pm")
  #    event.where = "Luigi's"
  #    event.reminder = {:minutes => 15, :method => 'email'}
  #    event.save
  #
  #9. Create an event with attendees
  #    event = Event.new(service)
  #    event.calendar = cal
  #    event.title = "Dinner with Kate"
  #    event.start_time = Time.parse("06/20/2009 at 5 pm")
  #    event.end_time = Time.parse("06/20/2009 at 8 pm")
  #    event.attendees => {:name => "Kate", :email => "kate@gmail.com"}
  #    event.save
  #
  #After an event object has been created or loaded, you can change any of the 
  #attributes like you would any other object.  Be sure to save the event to write changes
  #to the Google Calendar service.
  
  class Event < GData4Ruby::GDataObject
    EVENT_QUERY_FEED = "http://www.google.com/calendar/feeds/default/private/full/"
    EVENT_XML = "<entry xmlns='http://www.w3.org/2005/Atom'
    xmlns:gd='http://schemas.google.com/g/2005'>
  <category scheme='http://schemas.google.com/g/2005#kind'
    term='http://schemas.google.com/g/2005#event'></category>
  <title type='text'></title>
  <content type='text'></content>
  <gd:transparency
    value='http://schemas.google.com/g/2005#event.opaque'>
  </gd:transparency>
  <gd:eventStatus
    value='http://schemas.google.com/g/2005#event.confirmed'>
  </gd:eventStatus>
  <gd:where valueString=''></gd:where>
  <gd:when startTime=''
    endTime=''></gd:when>
</entry>"
    STATUS = {:confirmed => "http://schemas.google.com/g/2005#event.confirmed",
              :tentative => "http://schemas.google.com/g/2005#event.tentative",
              :cancelled => "http://schemas.google.com/g/2005#event.canceled"}
              
    TRANSPARENCY = {:free => "http://schemas.google.com/g/2005#event.transparent",
                    :busy => "http://schemas.google.com/g/2005#event.opaque"}
    
    #The content for the event
    attr_accessor :content
    #The location of the event
    attr_accessor :where
    #A flag for whether the event show as :free or :busy
    attr_accessor :transparency
    #A flag indicating the status of the event.  Values can be :confirmed, :tentative or :cancelled
    attr_accessor :status
    #Flag indicating whether it is an all day event
    attr_reader :all_day    
    #The reminder settings for the event, returned as a hash
    attr_reader :reminder
    #The date the event was last edited
    attr_reader :edited
    #Id of the parent calendar
    attr_reader :calendar_id
    
    #Creates a new Event.  Accepts a valid Service object and optional attributes hash.
    def initialize(service, attributes = {})
      super(service, attributes)
      @xml = EVENT_XML
      @transparency ||= :busy
      @status ||= :confirmed
      @attendees ||= []
      @all_day ||= false
      @reminder = []
      attributes.each do |key, value|
        self.send("#{key}=", value)
      end
    end
    
    #Sets the reminder options for the event.  Parameter must be a hash a :minutes key with a value of 5 up to 40320 (4 weeks)
    #and a :method key of with a value of one the following:
    #alert:: causes an alert to appear when a user is viewing the calendar in a browser
    #email:: sends the user an email message
    def reminder=(r)
      @reminder = r
    end
    
    #Returns the current event's Recurrence information
    def recurrence
      @recurrence
    end
    
    #Returns an array of the current attendees
    def attendees
      @attendees
    end
    
    def all_day=(value)
      puts 'all_day value = '+value.to_s if service.debug
      if value.is_a? String 
        @all_day = true if value.downcase == 'true'
        @all_day = false if value.downcase == 'false'
      else
        @all_day = value
      end
      puts 'after all_day value = '+@all_day.to_s if service.debug
      @all_day
    end
    
    #Accepts an array of email address/name pairs for attendees.  
    #  [{:name => 'Mike Reich', :email => 'mike@seabourneconsulting.com'}]
    #The email address is requried, but the name is optional
    def attendees=(a)
      raise ArgumentError, "Attendees must be an Array of email/name hash pairs" if not a.is_a?(Array) 
      @attendees = a
    end
    
    #Sets the event's recurrence information to a Recurrence object.  Returns the recurrence if successful,
    #false otherwise
    def recurrence=(r)
      raise ArgumentError, 'Recurrence must be a Recurrence object' if not r.is_a?(Recurrence)
      @recurrence = r
    end
    
    #Returns a duplicate of the current event as a new Event object
    def copy()
      e = Event.new(service)
      e.load(to_xml)
      e.calendar = @calendar
      return e
    end
    
    #Sets the start time of the Event.  Must be a Time object or a parsable string representation
    #of a time.
    def start_time=(str)
      raise ArgumentError, "Start Time must be either Time or String" if not str.is_a?String and not str.is_a?Time
      @start_time = if str.is_a?String
        Time.parse(str)      
      elsif str.is_a?Time
        str
      end
    end
    
    #Sets the end time of the Event.  Must be a Time object or a parsable string representation
    #of a time.
    def end_time=(str)
      raise ArgumentError, "End Time must be either Time or String" if not str.is_a?String and not str.is_a?Time
      @end_time = if str.is_a?String
        Time.parse(str)      
      elsif str.is_a?Time
        str
      end
    end
    
    #The event start time.  If a recurring event, the recurrence start time.
    def start_time
      return @start_time ? @start_time : @recurrence ? @recurrence .start_time : nil
    end
    
    #The event end time.  If a recurring event, the recurrence end time.
    def end_time
      return @end_time ? @end_time : @recurrence ? @recurrence.end_time : nil
    end

    
    #If the event does not exist on the Google Calendar service, save creates it.  Otherwise
    #updates the existing event data.  Returns true on success, false otherwise.
    def save
      raise CalendarNotEditable if not calendar.editable
      super
    end
    
    #Creates a new event
    def create
      service.send_request(GData4Ruby::Request.new(:post, @parent_calendar.content_uri, to_xml))
    end
    
    #Returns an XML representation of the event.
    def to_xml()
      xml = REXML::Document.new(super)
      xml.root.elements.each(){}.map do |ele|
        case ele.name
          when "content"
            ele.text = @content
          when "when"
            if not @recurrence
              puts 'all_day = '+@all_day.to_s if service.debug
              if @all_day
                puts 'saving as all-day event' if service.debug 
              else
                puts 'saving as timed event' if service.debug
              end
              ele.attributes["startTime"] = @all_day ? @start_time.strftime("%Y-%m-%d") : @start_time.utc.xmlschema
              ele.attributes["endTime"] = @all_day ? @end_time.strftime("%Y-%m-%d") : @end_time.utc.xmlschema
              set_reminder(ele)
            else
              xml.root.delete_element("/entry/gd:when")
              ele = xml.root.add_element("gd:recurrence")
              ele.text = @recurrence.to_recurrence_string
              set_reminder(ele) if @reminder
            end
          when "eventStatus"
            ele.attributes["value"] = STATUS[@status]
          when "transparency"
            ele.attributes["value"] = TRANSPARENCY[@transparency]
          when "where"
            ele.attributes["valueString"] = @where
          when "recurrence"
            puts 'recurrence element found' if service.debug
            if @recurrence
              puts 'setting recurrence' if service.debug
              ele.text = @recurrence.to_recurrence_string
            else
              puts 'no recurrence, adding when' if service.debug
              w = xml.root.add_element("gd:when")
              xml.root.delete_element("/entry/gd:recurrence")
              w.attributes["startTime"] = @all_day ? @start_time.strftime("%Y-%m-%d") : @start_time.xmlschema
              w.attributes["endTime"] = @all_day ? @end_time.strftime("%Y-%m-%d") : @end_time.xmlschema
              set_reminder(w)
            end
        end
      end        
      if not @attendees.empty?
        xml.root.elements.delete_all "gd:who"
        @attendees.each do |a|
          xml.root.add_element("gd:who", {"email" => a[:email], "valueString" => a[:name], "rel" => "http://schemas.google.com/g/2005#event.attendee"})
        end
      end
      xml.to_s
    end
    
    #The event's parent calendar
    def calendar 
      @parent_calendar = Calendar.find(service, {:id => @calendar_id}) if not @parent_calendar and @calendar_id
      return @parent_calendar
    end
    
    #Sets the event's calendar
    def calendar=(p)
      raise ArgumentError, 'Value must be a valid Calendar object' if not p.is_a? Calendar
      @parent_calendar = p
    end
    
    #Loads the event info from an XML string.
    def load(string)
      super(string)
      @xml = string
      @exists = true
      xml = REXML::Document.new(string)
      @etag = xml.root.attributes['etag']
      xml.root.elements.each(){}.map do |ele|
        case ele.name
          when 'id'
            @calendar_id, @id = @feed_uri.gsub("http://www.google.com/calendar/feeds/", "").split("/events/")
            @id = "#{@calendar_id}/private/full/#{@id}"
          when 'edited'
            @edited = Time.parse(ele.text)
          when 'content'
            @content = ele.text
          when "when"
            @start_time = Time.parse(ele.attributes['startTime'])
            @end_time = Time.parse(ele.attributes['endTime'])
            @all_day = !ele.attributes['startTime'].include?('T')
            @reminder = []
            ele.elements.each("gd:reminder") do |r|
              rem = {}
              rem[:minutes] = r.attributes['minutes'] if r.attributes['minutes']
              rem[:method] = r.attributes['method'] if r.attributes['method']
              @reminder << rem
            end
          when "where"
            @where = ele.attributes['valueString']
          when "link"
            if ele.attributes['rel'] == 'edit'
              @edit_feed = ele.attributes['href']
            end
          when "who"        
            @attendees << {:email => ele.attributes['email'], :name => ele.attributes['valueString'], :role => ele.attributes['rel'].gsub("http://schemas.google.com/g/2005#event.", ""), :status => ele.elements["gd:attendeeStatus"] ? ele.elements["gd:attendeeStatus"].attributes['value'].gsub("http://schemas.google.com/g/2005#event.", "") : ""}
          when "eventStatus"
            @status =  ele.attributes["value"].gsub("http://schemas.google.com/g/2005#event.", "").to_sym 
          when 'recurrence'
            @recurrence = Recurrence.new(ele.text)
          when "transparency"
             @transparency = case ele.attributes["value"]
                when "http://schemas.google.com/g/2005#event.transparent" then :free
                when "http://schemas.google.com/g/2005#event.opaque" then :busy
             end
        end      
      end
    end
    
    #Reloads the event data from the Google Calendar Service.  Returns true if successful,
    #false otherwise.
    def reload
      return false if not @exists
      t = Event.find(service, {:id => @id})
      if t and load(t.to_xml)
         return true
      end
      return false
    end
    
    #Finds an Event based on a text query or by an id.  Parameters are:
    #*service*::  A valid Service object to search.
    #*query*:: either a string containing a text query to search by, or a hash containing an +id+ key with an associated id to find, or a +query+ key containint a text query to search for, or a +title+ key containing a title to search.  All searches are case insensitive.
    #*args*:: a hash containing optional additional query paramters to use.  Limit a search to a single calendar by passing the calendar id as {:calendar => calendar.id}.  See here[http://code.google.com/apis/calendar/data/2.0/developers_guide_protocol.html#RetrievingEvents] and here[http://code.google.com/apis/gdata/docs/2.0/reference.html#Queries] for a full list of possible values.  Example: 
    # {'max-results' => '100'}
    #If an ID is specified, a single instance of the event is returned if found, otherwise false.
    #If a query term or title text is specified, and array of matching results is returned, or an empty array if nothing
    #was found.
    def self.find(service, query, args = {})
      raise ArgumentError, 'query must be a hash or string' if not query.is_a? Hash and not query.is_a? String
      if query.is_a? Hash and query[:id]
        id = query[:id]
        puts "id passed, finding event by id" if service.debug
        puts "id = "+id if service.debug
        d = service.send_request(GData4Ruby::Request.new(:get, "http://www.google.com/calendar/feeds/"+id, {"If-Not-Match" => "*"}))
        puts d.inspect if service.debug
        if d
          return get_instance(service, d)
        end
      else
        results = []
        if query.is_a?(Hash)
          args["q"] = query[:query] if query[:query]
          args['title'] = query[:title] if query[:title]
        else
          args["q"] = CGI::escape(query) if query != ''
        end
        if args[:calendar]
          cal = Calendar.find(service, {:id => args[:calendar]})
          args.delete(:calendar)
          ret = service.send_request(GData4Ruby::Request.new(:get, cal.content_uri, nil, nil, args))
          xml = REXML::Document.new(ret.body).root
          xml.elements.each("entry") do |e|
            results << get_instance(service, e)
          end
        else
          service.calendars.each do |cal|
            ret = service.send_request(GData4Ruby::Request.new(:get, cal.content_uri, nil, nil, args))
            xml = REXML::Document.new(ret.body).root
            xml.elements.each("entry") do |e|
              results << get_instance(service, e)
            end
          end
        end
        return results
      end
      return false
    end
    
    #Returns true if the event exists on the Google Calendar Service.
    def exists?
      return @exists
    end
  
    private     
    def set_reminder(ele)
      num = ele.elements.delete_all "gd:reminder"
      puts 'num = '+num.size.to_s if service.debug
      if @reminder
        @reminder.each do |reminder|
          puts 'reminder added' if service.debug
          e = ele.add_element("gd:reminder")
          e.attributes['minutes'] = reminder[:minutes].to_s if reminder[:minutes]
          if reminder[:method] 
            e.attributes['method'] = reminder[:method]
          else
            e.attributes['method'] = 'email'
          end
        end
      end
    end

    def self.get_instance(service, d)
      if d.is_a? Net::HTTPOK
        xml = REXML::Document.new(d.read_body).root
        if xml.name == 'feed'
          xml = xml.elements.each("entry"){}[0]
        end
      else
        xml = d
      end
      ele = GData4Ruby::Utils::add_namespaces(xml)
      e = Event.new(service)
      e.load(ele.to_s)
      e
    end
  end
end

