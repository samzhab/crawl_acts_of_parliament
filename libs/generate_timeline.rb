#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2021 Samuel Y. Ayele
require 'json'
require 'byebug'
require 'fileutils'
require 'yaml'

class GenerateTimeline
  CENTURIES = %w(18 19 20).freeze
  DECADES = %w(00 10 20 30 40 50 60 70 80 90).freeze
  LETTERS = %w(A B C D E F G H I J K
               L M N O P Q R S T U V W X Y Z).freeze
  def generate(path)
    puts 'File not found' and return unless File.exist?(
      path
    )

    json_data = JSON.parse(File.read(path))
    sorted_json = json_data.group_by { |h| h['year'] }.sort.to_h
    formatted_json = { 'title' => 'Consolidated Acts of Parliament',
                      'show_today' => true, 'periods' => {} }
    formatted_json = process_sorted_json(formatted_json, sorted_json)
    format_and_write_to_yaml(formatted_json)
  end

  def process_sorted_json(formatted_json, sorted_json)
    sorted_json.each do |year, acts|
      decade = ((year.to_i / 10).to_i * 10)
      next if decade.zero?

      formatted_json['periods'] = format_json_by_decade(formatted_json['periods'], decade, acts)
    end
    formatted_json
  end

  def format_json_by_decade(formatted_json, decade, acts)
    if formatted_json[decade].nil?
      formatted_json[decade] = {}
      formatted_json[decade]['acts'] = [acts]
    else
      formatted_json[decade]['acts'] << acts
    end
    formatted_json[decade]['acts'].flatten!
    formatted_json.sort.to_h
  end

  def write_to_yaml_file(formatted_json)
    Process.spawn('mkdir YAMLs') unless Dir.exist?('YAMLs')
    sleep 0.2
    File.open('YAMLs/all_parliament_acts.yml', 'a+') do |file|
      file.write(formatted_json.to_yaml)
      file.close
    end
  end

  def format_and_write_to_yaml(formatted_json)
    if File.exist?('YAMLs/all_parliament_acts.yml')
      Process.spawn('rm YAMLs/all_parliament_acts.yml')
    end
    write_to_yaml_file({ 'title' => 'Consolidated Acts of Parliament', 'show_today' => true })
    json_to_write = { 'periods' => [] }
    formatted_json['periods'].each do |period, hash|
      acts = hash['acts'].map { |act| { "January #{act['year']}" => act['name'] } }
      json_to_write['periods'] << { 'name' => "#{period}'s", 'acts' => acts }
    end
    write_to_yaml_file(json_to_write)
    json_to_write
  end
end

timeliner = GenerateTimeline.new
timeliner.generate('JSONs/all_parliament_acts.json')
