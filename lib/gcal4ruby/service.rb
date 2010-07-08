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
require 'gdata4ruby'
require 'gdata4ruby/gdata_object'
require 'gdata4ruby/utils/utils'
require 'gdata4ruby/acl/access_rule'
require 'gcal4ruby/calendar'
require 'gcal4ruby/event'
require 'gcal4ruby/recurrence'
require 'rexml/document'

module GCal4Ruby
  #The service class is the main handler for all direct interactions with the 
  #Google Calendar API.  A service represents a single user account.  Each user
  #account can have multiple calendars, so you'll need to find the calendar you
  #want from the service, using the Calendar#find class method.
  #=Usage
  #
  #1. Authenticate
  #    service = Service.new
  #    service.authenticate("user@gmail.com", "password")
  #
  #2. Get Calendar List
  #    calendars = service.calendars
  #
  class Service < GData4Ruby::Service
    CALENDAR_LIST_FEED = 'http://www.google.com/calendar/feeds/default/allcalendars/full'
    
    #Convenience attribute contains the currently authenticated account name
    attr_reader :account
        
    # The token returned by the Google servers, used to authorize all subsequent messages
    attr_reader :auth_token
    
    # Determines whether GCal4Ruby ensures a calendar is public.  Setting this to false can increase speeds by 
    # 50% but can cause errors if you try to do something to a calendar that is not public and you don't have
    # adequate permissions
    attr_accessor :check_public
    
    #Accepts an optional attributes hash for initialization values
    def initialize(attributes = {})
      super(attributes)
      attributes.each do |key, value|
        self.send("#{key}=", value)
      end    
      @check_public ||= true
    end
    
    def default_event_feed
      return "http://www.google.com/calendar/feeds/#{@account}/private/full"
    end
  
    # The authenticate method passes the username and password to google servers.  
    # If authentication succeeds, returns true, otherwise raises the AuthenticationFailed error.
    def authenticate(username, password, service='cl')
      super(username, password, service)
    end
    
    #Helper function to reauthenticate to a new Google service without having to re-set credentials.
    def reauthenticate(service='cl')
      authenticate(@account, @password, service)
    end
  
    #Returns an array of Calendar objects for each calendar associated with 
    #the authenticated account.
    def calendars
      if not @auth_token
         raise NotAuthenticated
      end
      ret = send_request(GData4Ruby::Request.new(:get, CALENDAR_LIST_FEED, nil, {"max-results" => "10000"}))
      cals = []
      REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
        entry = GData4Ruby::Utils.add_namespaces(entry)
        cal = Calendar.new(self)
        cal.load(entry.to_s)
        cals << cal
      end
      return cals
    end
    
    #Returns an array of Event objects for each event in this account
    def events
      if not @auth_token
         raise NotAuthenticated
      end
      ret = send_request(GData4Ruby::Request.new(:get, default_event_feed, nil, {"max-results" => "10000"}))
      events = []
      REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
        entry = GData4Ruby::Utils.add_namespaces(entry)
        event = Event.new(self)
        event.load(entry.to_s)
        events << event
      end
      return events
    end
    
    #Helper function to return a formatted iframe embedded google calendar.  Parameters are:
    #1. *cals*: either an array of calendar ids, or <em>:all</em> for all calendars, or <em>:first</em> for the first (usally default) calendar
    #2. *params*: a hash of parameters that affect the display of the embedded calendar.  Accepts any parameter that the google iframe recognizes.  Here are the most common:
    #   height:: the height of the embedded calendar in pixels
    #   width:: the width of the embedded calendar in pixels
    #   title:: the title to display
    #   bgcolor:: the background color.  Limited choices, see google docs for allowable values.
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
    #3. *colors*: a hash of calendar ids as key and color values as associated hash values.  Example: {'test@gmail.com' => '#7A367A'} 
    def to_iframe(cals, params = {}, colors = {})
      params[:height] ||= "600"
      params[:width] ||= "600"
      params[:title] ||= (self.account ? self.account : '')
      params[:bgcolor] ||= "#FFFFFF"
      params[:border] ||= "0"
      params.each{|key, value| params[key] = CGI::escape(value)}
      output = "#{params.to_a.collect{|a| a.join("=")}.join("&")}&"
      
      if cals.is_a?(Array)
        for c in cals
          output += "src=#{c}&"
          if colors and colors[c]
            output += "color=%23#{colors[c].gsub("#", "")}&"
          end
        end
      elsif cals == :all
        cal_list = calendars()
        for c in cal_list
          output += "src=#{c.id}&"
        end
      elsif cals == :first
        cal_list = calendars()
        output += "src=#{cal_list[0].id}&"
      end
          
      "<iframe src='http://www.google.com/calendar/embed?#{output}' style='#{params[:border]} px solid;' width='#{params[:width]}' height='#{params[:height]}' frameborder='#{params[:border]}' scrolling='no'></iframe>"
    end
  end
end