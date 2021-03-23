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
  def generate
    return unless File.exist?('JSONs/all_parliament_acts.json')

    # acts = {}
    LETTERS.each do |letter|
      # create an array to hold all acts starting with A
      # open 'A' acts json file, loop through acts
      # array it out hash it out with key (letter, century, decade) array it out
      # an Array named A[] holds {:1960sA => [act1,act2,act34,act23],
      # :1970sA => [act5, act3, act23]}
      json_data = JSON.parse(File.read("JSONs/#{letter}/#{letter}_parliament_acts.json"))
      # interesting_acts = []

      CENTURIES.each do |_century|
        DECADES.each do |_decade|
          json_data.each do |act|
            # target_year = "#{century}#{decade}"
            # interesting_acts << act if act['year'][/target_year/]
            # create an empty hash
            # for each century+decade, loop through acts and grab act hash
            # with key matching century+decade
            # if year on act matches current century+decade in loop collect it
          end
        end
      end
    end
    # json_data.each do |_act|
    # "#{act[name]} #{act[category]} #{code} "\
    # "has regulations - #{has_regulations} "

    # title: "Consolidated Acts of Parliament"
    # show_today: true
    # periods:
    #   - name: 1800's
    #   - acts:
    #     - December 1990:  Neil moves to California
    #     - August 2008:  Neil moves to Chicago
    #   - name: 1810's
    #   - acts:
    #     - June 2010: Neil spends a summer in Paris for study abroad
    #   ...     ...     ...     ...
    #   - name: 2020's
    #   - acts:
    #     - July 2020: "#{act[name]} #{act[category]} #{code} "\
    #     "has regulations - #{has_regulations} "
    # end
  end
end
timeliner = GenerateTimeline.new
timeliner.generate
