# frozen_string_literal: true

# Copyright (c) 2021 Samuel Y. Ayele
require 'test/unit'

require_relative '../libs/generate_timeline'

class GenerateTimelineTest < Test::Unit::TestCase
  def test_generate
    timeliner = GenerateTimeline.new
    path = 'tests/JSONs/all_parliament_acts.json'
    assert_true File.exist?(path)
    timeliner.generate(path)
    sleep 0.2
    assert_true File.exist?("#{Dir.pwd}/YAMLs/all_parliament_acts.yml")
  rescue StandardError
    assert_true false
  end

  def test_process_sorted_json
    sample_json = {
      '2016' => [{ 'name' => 'Canada and Taiwan Territories Tax Arrangement Act, 2016',
                   'year' => '2016' }],
      '2020' => [{ 'name' => 'Canada Emergency Response Benefit Act', 'year' => '2020' }]
    }
    formatted_json = { 'title' => 'Consolidated Acts of Parliament',
      'show_today' => true, 'periods' => {} }
    timeliner = GenerateTimeline.new
    response = timeliner.process_sorted_json(formatted_json, sample_json)
    expected_response = { 'title' => 'Consolidated Acts of Parliament', 'show_today' => true,
      'periods' =>
          { 2010 => { 'acts' => [{
            'name' => 'Canada and Taiwan Territories Tax Arrangement Act, 2016', 'year' => '2016'
          }] },
            2020 => { 'acts' => [{
              'name' => 'Canada Emergency Response Benefit Act', 'year' => '2020'
            }] } } }

    assert_true response == expected_response
  end

  def test_format_json_by_decade
    expected_json = { 1870 =>
                              { 'acts' =>
                                          [{ 'name' => 'Works on the Ottawa River' }] } }
    timeliner = GenerateTimeline.new
    acts = { 'name' => 'Works on the Ottawa River' }
    response = timeliner.format_json_by_decade({}, 1870, acts)
    assert_true response == expected_json
  end

  def test_write_to_yaml_file
    formatted_json = { 1870 =>
                               { 'acts' =>
                                           [{ 'name' => 'Works on the Ottawa River' }] } }
    timeliner = GenerateTimeline.new
    response = timeliner.write_to_yaml_file(formatted_json)
    assert_equal response, nil
  end

  def test_format_and_write_to_yaml
    timeliner = GenerateTimeline.new
    formatted_json = { 'title' => 'Consolidated Acts of Parliament', 'show_today' => true,
      'periods' =>
          { 2010 => { 'acts' => [{
            'name' => 'Canada and Taiwan Territories Tax Arrangement Act, 2016', 'year' => '2016'
          }] },
            2020 => { 'acts' => [{
              'name' => 'Canada Emergency Response Benefit Act', 'year' => '2020'
            }] } } }
    expected_response = { 'periods' => [
      { 'name' => "2010's",
        'acts' => [{ 'January 2016'=>'Canada and Taiwan Territories Tax Arrangement Act, 2016' }] },
      { 'name' => "2020's",
        'acts' => [{ 'January 2020'=>'Canada Emergency Response Benefit Act' }] }
    ] }
    response = timeliner.format_and_write_to_yaml(formatted_json)
    assert_true response == expected_response
    file_exists = File.exist?('YAMLs/all_parliament_acts.yml')
    assert_true file_exists
  end
end
