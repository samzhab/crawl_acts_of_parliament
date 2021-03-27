# frozen_string_literal: true

# Copyright (c) 2021 Samuel Y. Ayele
require 'test/unit'

require_relative '../generate_timeline'

class GenerateTimelineTest < Test::Unit::TestCase
  def test_source_json
    assert_true File.exist?("#{Dir.pwd}/JSONs/all_parliament_acts.json")
    assert_true Dir.exist?('YAMLs')
  end

  def test_generate
    timeliner = GenerateTimeline.new
    timeliner.generate
    sleep 0.2
    assert_true File.exist?("#{Dir.pwd}/YAMLs/all_parliament_acts.yml")
  rescue StandardError
    assert_true false
  end

  def test_process_sorted_json
    sample_json = {
      '2016' => [{ 'name' => 'Canada and Taiwan Territories Tax Arrangement Act, 2016',
                 'year' => '2016', 'code' => 'c. 13, s. 3' }],
      '2020' => [{ 'name' => 'Canada Emergency Response Benefit Act', 'year' => '2020',
                 'code' => 'c. 5, s. 8' }]
    }
    formatted_json = { 'title' => 'Consolidated Acts of Parliament',
      'show_today' => true, 'periods' => {} }
    timeliner = GenerateTimeline.new
    response = timeliner.process_sorted_json(formatted_json, sample_json)
    assert_expectations(response)
  end

  def assert_expectations(response)
    expected_response = { 'title' => 'Consolidated Acts of Parliament', 'show_today' => true,
      'periods' =>
          { 2010 => { 'acts' => [{
            'name' => 'Canada and Taiwan Territories Tax Arrangement Act, 2016', 'year' => '2016',
            'code' => 'c. 13, s. 3'
          }] },
            2020 => { 'acts' => [{
              'name' => 'Canada Emergency Response Benefit Act', 'year' => '2020',
            'code' => 'c. 5, s. 8'
            }] } } }
    assert_true response == expected_response
  end
end
