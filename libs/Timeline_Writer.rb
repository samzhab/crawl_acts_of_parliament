#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2021 Samuel Y. Ayele
require 'json'
require 'byebug'

# ------------------------------------------------------------------------------

class TimelineWriter
  def start
    total_xml_count = 0
    timeline_file = create_timeline_file
    acts_hash = open_json_file
    display_message(acts_hash, 'count')
    acts_hash.each do |act|
      next unless act['year'][/\d\d\d\d/]

      display_message(act, 'status')
      add_to_timeline_file(timeline_file, act)
      display_message(act, 'notice')
      total_xml_count += 1
    end
    close_timeline_file(timeline_file)
    puts '[Create Timeline] All acts mapped.'
    display_saved_timeline_xml(acts_hash.count, total_xml_count)
    # ('A'..'Z').each do |letter|
    #   byebug
    #   # read json file with all acts
    #   add_to_timeline_file(timeline_file, act)
    # end
    # loop through each json element
    # open created timeline file
    # add event element from json to file and return back to loop
  end

  def add_to_timeline_file(timeline_file, act)
    timeline_file.write("\n\t\t<event>"\
          "\n\t\t\t<start>#{act['year'][/\d\d\d\d/]}-01-20 00:10:00</start>"\
          "\n\t\t\t<end>#{act['year'][/\d\d\d\d/]}-01-22 00:10:00</end>"\
          "\n\t\t\t<text>#{act['name']}</text>"\
          "\n\t\t\t<progress>0</progress>"\
          "\n\t\t\t<fuzzy>False</fuzzy>"\
          "\n\t\t\t<locked>False</locked>"\
          "\n\t\t\t<ends_today>False</ends_today>"\
          "\n\t\t\t<description>#{act['name']} #{act['category']} "\
          "#{act['code']} has regulations- #{act['has_regulations']} "\
          "been repealed-#{act['repealed']}</description> "\
          "\n\t\t\t<default_color>211,211,211</default_color>"\
        "\n\t\t</event>")
  end

  def open_json_file
    json_file = File.read('JSONs/all_parliament_acts.json')
    JSON.parse(json_file)
  end

  def create_timeline_file
    File.open('Acts_of_Parliament.timeline', 'w') do |f|
      f << %(<?xml version='1.0' encoding='utf-8'?>\n<timeline>)\
    "\n\t<version>2.3.1 (b518d5113b65 2020-11-12)</version>"\
    "\n\t<timetype>gregoriantime</timetype>"\
      "\n\t<categories>"\
      "\n\t</categories>"\
      "\n\t<events>"
    end
  end

  def close_timeline_file(timeline_file)
    timeline_file.write("\n\t</events>"\
        "\n<view>"\
        "\n\t<displayed_period>"\
        "\n\t\t<start>2020-11-18 01:13:54</start>"\
        "\n\t\t<end>2020-11-25 16:53:37</end>"\
        "\n\t</displayed_period>"\
        "\n\t<hidden_categories>"\
        "\n\t</hidden_categories>"\
        "\n</view>"\
        "\n</timeline>")
    timeline_file.close
  end

  def display_message(act, flag)
    case flag
    when 'notice'
      puts "[Notice][Create Timeline] Finished processing ... #{act['name']}"
    when 'status'
      puts "[Status][Create Timeline] Processing #{act['name']} now..."
    when 'count_json_resource'
      puts "[Status][Create Timeline] Retrieved total #{act.count} now..."
    end
  end

  def display_saved_timeline_xml(total_json_count, total_xml_count)
    puts "[Status][Create Timeline] Stored total #{total_xml_count} out
          of total #{total_json_count} acts"
  end

  def display_error(error, url)
    puts "[Error][Create Timeline] - #{error} for #{url}"
  end
end

timeline_writer = TimelineWriter.new
timeline_writer.start
