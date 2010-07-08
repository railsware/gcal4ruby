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
require 'gdata4ruby/acl/access_rule'
module GCal4Ruby
  #The Calendar Class is the representation of a Google Calendar.  Each user account 
  #can have multiple calendars.  You must have an authenticated Service object before 
  #using the Calendar object.
  #=Usage
  #All usages assume a successfully authenticated Service.
  #1. Create a new Calendar
  #    cal = Calendar.new(service)
  #
  #2. Find a calendar by ID
  #    cal = Calendar.find(service, {:id => cal_id})
  #
  #3. Get all calendar events
  #    cal = Calendar.find(service, {:id => cal_id})
  #    events = cal.events
  #
  #4. Find an existing calendar by title
  #    cal = Calendar.find(service, {:title => "New Calendar"})
  #
  #5. Find all calendars containing a search term
  #    cal = Calendar.find(service, "Soccer Team")
  #
  #After a calendar object has been created or loaded, you can change any of the 
  #attributes like you would any other object.  Be sure to save the calendar to write changes
  #to the Google Calendar service.
  class Calendar < GData4Ruby::GDataObject
    CALENDAR_FEED = "http://www.google.com/calendar/feeds/default/owncalendars/full/"
    CALENDAR_QUERY_FEED = "http://www.google.com/calendar/feeds/default/calendars/"
    CALENDAR_XML = "<entry xmlns='http://www.w3.org/2005/Atom' 
         xmlns:gd='http://schemas.google.com/g/2005' 
         xmlns:gCal='http://schemas.google.com/gCal/2005'>
    <title type='text'></title>
    <summary type='text'></summary>
    <gCal:timezone value='America/Los_Angeles'></gCal:timezone>
    <gCal:hidden value='false'></gCal:hidden>
    <gCal:color value='#2952A3'></gCal:color>
    <gd:where rel='' label='' valueString='Oakland'></gd:where>
  </entry>"
    
    #A short description of the calendar
    attr_accessor :summary
    
    #Boolean value indicating the calendar visibility
    attr_accessor :hidden
    
    #The calendar timezone[http://code.google.com/apis/calendar/docs/2.0/reference.html#gCaltimezone]
    attr_accessor :timezone
    
    #The calendar color.  Must be one of these[http://code.google.com/apis/calendar/docs/2.0/reference.html#gCalcolor] values.
    attr_accessor :color
    
    #The calendar geo location, if any
    attr_accessor :where
    
    #A boolean value indicating whether the calendar appears by default when viewed online
    attr_accessor :selected
    
    #A flag indicating whether the calendar is editable by this account 
    attr_reader :editable
    
    #Accepts a Service object and an optional attributes hash for initialization.  Returns the new Calendar 
    #if successful, otherwise raises the InvalidService error.
    def initialize(service, attributes = {})
      super(service, attributes)
      if !service.is_a?(Service)
        raise InvalidService
      end
      @xml = CALENDAR_XML
      @service ||= service
      @exists = false
      @title ||= ""
      @summary ||= ""
      @public ||= false
      @hidden ||= false
      @timezone ||= "America/Los_Angeles"
      @color ||= "#2952A3"
      @where ||= ""
      attributes.each do |key, value|
        self.send("#{key}=", value)
      end
      return true
    end
    
    #Returns true if the calendar exists on the Google Calendar system (i.e. was 
    #loaded or has been saved).  Otherwise returns false.
    def exists?
      return @exists
    end
    
    #Returns true if the calendar is publically accessable, otherwise returns false.
    def public?
      return @public
    end
    
    #Returns an array of Event objects corresponding to each event in the calendar.
    def events
      events = []
      ret = @service.send_request(GData4Ruby::Request.new(:get, @content_uri))
      REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
        entry = GData4Ruby::Utils.add_namespaces(entry)
        e = Event.new(service)
        if e.load(entry.to_s)
          events << e
        end
      end
      return events
    end
    
    
    #Saves the calendar.
    def save
      public = @public
      ret = super
      return ret if public == @public
      if public
        puts 'setting calendar to public' if service.debug
        rule = GData4Ruby::ACL::AccessRule.new(service, self)
        rule.role = 'http://schemas.google.com/gCal/2005#read'
        rule.save
      else
        rule = GData4Ruby::ACL::AccessRule.find(service, self, {:user => 'default'})
        rule.delete if rule
      end
      reload
    end
    
    #Set the calendar to public (p = true) or private (p = false).  Publically viewable
    #calendars can be accessed by anyone without having to log in to google calendar.  See
    #Calendar#to_iframe on how to display a public calendar in a webpage.
    def public=(p)
      @public = p
    end
    
    #Creates a new instance of the object
    def create
      return service.send_request(GData4Ruby::Request.new(:post, CALENDAR_FEED, to_xml()))
    end
    
    #Finds a Calendar based on a text query or by an id.  Parameters are:
    #*service*::  A valid Service object to search.
    #*query*:: either a string containing a text query to search by, or a hash containing an +id+ key with an associated id to find, or a +query+ key containint a text query to search for, or a +title+ key containing a title to search.
    #*args*:: a hash containing optional additional query paramters to use.  See http://code.google.com/apis/gdata/docs/2.0/reference.html#Queries for a full list of possible values.  Example: 
    # {'max-results' => '100'}
    #If an ID is specified, a single instance of the calendar is returned if found, otherwise false.
    #If a query term or title text is specified, and array of matching results is returned, or an empty array if nothing
    #was found.
    def self.find(service, query, args = {})
      raise ArgumentError, 'query must be a hash or string' if not query.is_a? Hash and not query.is_a? String
      if query.is_a? Hash and query[:id]
        id = query[:id]
        puts "id passed, finding calendar by id" if service.debug
        puts "id = "+id if service.debug
        d = service.send_request(GData4Ruby::Request.new(:get, CALENDAR_FEED+id, {"If-Not-Match" => "*"}))
        puts d.inspect if service.debug
        if d
          return get_instance(service, d)
        end
      else
        #fugly, but Google doesn't provide a way to query the calendar feed directly
        old_public = service.check_public
        service.check_public = false
        results = []
        cals = service.calendars
        cals.each do |cal|
          if query.is_a?(Hash)
            results << cal if query[:query] and cal.title.downcase.include? query[:query].downcase
            results << cal if query[:title] and cal.title == query[:title]
          else
            results << cal if cal.title.downcase.include? query.downcase
          end
        end
        service.check_public = old_public
        return results
      end
      return false
    end
    
    #Reloads the calendar objects information from the stored server version.  Returns true
    #if successful, otherwise returns false.  Any information not saved will be overwritten.
    def reload
      return false if not @exists
      t = Calendar.find(service, {:id => @id})
      if t
        load(t.to_xml)
      else
        return false
      end
    end
    
    #Returns the xml representation of the Calenar.
    def to_xml
      xml = REXML::Document.new(super)
      xml.root.elements.each(){}.map do |ele|
        case ele.name
        when "summary"
          ele.text = @summary
        when "timezone"
          ele.attributes["value"] = @timezone
        when "hidden"
          ele.attributes["value"] = @hidden.to_s
        when "color"
          ele.attributes["value"] = @color
        when "selected"
          ele.attributes["value"] = @selected.to_s
        end
      end
      xml.to_s
    end
  
    #Loads the Calendar with returned data from Google Calendar feed.  Returns true if successful.
    def load(string)
      super(string)
      @exists = true
      @xml = string
      xml = REXML::Document.new(string)
      xml.root.elements.each(){}.map do |ele|
        case ele.name
          when "id"
            @id = ele.text.gsub("http://www.google.com/calendar/feeds/default/calendars/", "")
          when 'summary'
            @summary = ele.text
          when "color"
            @color = ele.attributes['value']
          when 'hidden'
            @hidden = ele.attributes["value"] == "true" ? true : false
          when 'timezone'
            @timezone = ele.attributes["value"]
          when "selected"
            @selected = ele.attributes["value"] == "true" ? true : false
          when "link"
            if ele.attributes['rel'] == 'edit'
              @edit_feed = ele.attributes['href']
            end
          when 'accesslevel'
            @editable = (ele.attributes["value"] == 'editor' or ele.attributes["value"] == 'owner' or ele.attributes["value"] == 'root')
        end
      end
      
      if @service.check_public
        puts "Getting ACL Feed" if @service.debug
        
        #rescue error on shared calenar ACL list access
        begin 
          ret = @service.send_request(GData4Ruby::Request.new(:get, @acl_uri))
        rescue Exception => e
          puts "ACL Feed Get Failed: #{e.inspect}" if @service.debug
          @public = false
          return true
        end
        r = REXML::Document.new(ret.read_body)
        r.root.elements.each("entry") do |ele|
          e = GData4Ruby::ACL::AccessRule.new(service, self)
          ele = GData4Ruby::Utils.add_namespaces(ele)
          e.load(ele.to_s)
          puts 'acl rule = '+e.inspect if service.debug
          @public = (e.role.include? 'read' and e.user == 'default')
          puts 'public = '+@public.to_s if service.debug
          break if @public
        end
      else
        @public = false
      end
      return true
    end
    
    #Helper function to return a formatted iframe embedded google calendar.  Parameters are:
    #1. *params*: a hash of parameters that affect the display of the embedded calendar.  Accepts any parameter that the google iframe recognizes.  Here are the most common:
    #   height:: the height of the embedded calendar in pixels
    #   width:: the width of the embedded calendar in pixels
    #   title:: the title to display
    #   bgcolor:: the background color.  Limited choices, see google docs for allowable values.
    #   color:: the color of the calendar elements.  Limited choices, see google docs for allowable values.
    #   showTitle:: set to '0' to hide the title
    #   showDate:: set to '0' to hide the current date
    #   showNav:: set to '0 to hide the navigation tools
    #   showPrint:: set to '0' to hide the print icon
    #   showTabs:: set to '0' to hide the tabs
    #   showCalendars:: set to '0' to hide the calendars selection drop down
    #   showTz:: set to '0' to hide the timezone selection
    #   border:: the border width in pixels
    #   dates:: a range of dates to display in the format of 'yyyymmdd/yyyymmdd'.  Example: 20090820/20091001
    #   privateKey:: use to display a private calendar.  You can find this key under the calendar settings pane of the Google Calendar website.
    #   ctz:: The timezone to convert event times to
    def to_iframe(params = {})
      params[:height] ||= "600"
      params[:width] ||= "600"
      params[:title] ||= (self.title ? self.title : '')
      params[:bgcolor] ||= "#FFFFFF"
      params[:color] ||= "#2952A3"
      params[:border] ||= "0"
      params.each{|key, value| params[key] = CGI::escape(value)}
      output = "#{params.to_a.collect{|a| a.join("=")}.join("&")}"
    
      output += "&src=#{id}"
          
      "<iframe src='http://www.google.com/calendar/embed?#{output}' style='#{params[:border]} px solid;' width='#{params[:width]}' height='#{params[:height]}' frameborder='#{params[:border]}' scrolling='no'></iframe>"  
    end
    
    #Helper function to return a specified calendar id as a formatted iframe embedded google calendar.  This function does not require loading the calendar information from the Google calendar
    #service, but does require you know the google calendar id. 
    #1. *id*: the unique google assigned id for the calendar to display.
    #2. *params*: a hash of parameters that affect the display of the embedded calendar.  Accepts any parameter that the google iframe recognizes.  Here are the most common:
    #   height:: the height of the embedded calendar in pixels
    #   width:: the width of the embedded calendar in pixels
    #   title:: the title to display
    #   bgcolor:: the background color.  Limited choices, see google docs for allowable values.
    #   color:: the color of the calendar elements.  Limited choices, see google docs for allowable values.
    #   showTitle:: set to '0' to hide the title
    #   showDate:: set to '0' to hide the current date
    #   showNav:: set to '0 to hide the navigation tools
    #   showPrint:: set to '0' to hide the print icon
    #   showTabs:: set to '0' to hide the tabs
    #   showCalendars:: set to '0' to hide the calendars selection drop down
    #   showTz:: set to '0' to hide the timezone selection
    #   border:: the border width in pixels
    #   dates:: a range of dates to display in the format of 'yyyymmdd/yyyymmdd'.  Example: 20090820/20091001
    #   privateKey:: use to display a private calendar.  You can find this key under the calendar settings pane of the Google Calendar website.
    def self.to_iframe(id, params = {})
      params[:height] ||= "600"
      params[:width] ||= "600"
      params[:bgcolor] ||= "#FFFFFF"
      params[:color] ||= "#2952A3"
      params[:border] ||= "0"
      params.each{|key, value| params[key] = CGI::escape(value)}
      output = "#{params.to_a.collect{|a| a.join("=")}.join("&")}"
    
      output += "&src=#{id}"
          
      "<iframe src='http://www.google.com/calendar/embed?#{output}' style='#{params[:border]} px solid;' width='#{params[:width]}' height='#{params[:height]}' frameborder='#{params[:border]}' scrolling='no'></iframe>"  
    end
  
    private
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
      cal = Calendar.new(service)
      cal.load(ele.to_s)
      cal
    end
  end 
end