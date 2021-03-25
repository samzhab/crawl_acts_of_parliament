# frozen_string_literal: true

# Copyright (c) 2021 Samuel Y. Ayele
require 'test/unit'
require 'webmock'
require 'json'
require 'addressable'
require 'rest-client'
require 'byebug'
require 'nokogiri'
require 'down'
require 'fileutils'

require_relative '../libs/criminal_notebook_crawl'

include WebMock::API
WebMock.enable!
class CriminalNotebookCrawlTest < Test::Unit::TestCase
  BASE_URL = 'http://criminalnotebook.ca/index.php/'

  LIST = {
    'List_of_Summary_Conviction_Offences'  => ['summary conviction'],
    'List_of_Straight_Indictable_Offences' => ['indictable offence'],
    'List_of_Hybrid_Offences'              => %w(hybrid)
  }.freeze

  LIST.each do |offence, _values|
    url = "#{BASE_URL}#{offence}"
    body = File.read("webmocks/criminalnotebook/#{offence}.html")
    # ------------------------------------------------------stub requests
    stub_request(:get, url)
      .with(headers: { 'Accept'          => '*/*',
                       'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                       'Host'            => 'criminalnotebook.ca',
                       'User-Agent'      => 'rest-client/2.1.0 (linux-gnu x86_64) ruby/2.6.6p146' })
      .to_return(status: 200, body: body, headers: {})
  end

  def test_create_folders
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.class::LIST.each do |offence, _values|
      notebook_crawl.create_folders(offence)
    end
    sleep 0.2
    directories_exists(notebook_crawl)
  end

  def directories_exists(notebook_crawl)
    [notebook_crawl.class::JSON_PATH, notebook_crawl.class::TEXT_PATH].each do |path|
      notebook_crawl.class::LIST.each do |offence, _values|
        return false unless Dir.exist?("#{path}/#{offence}")
      end
    end
    true
  end

  def test_get_request
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.class::LIST.each do |offence, _values|
      url = "#{notebook_crawl.class::BASE_URL}#{offence}"
      response = notebook_crawl.get_request(url, {})
      assert_equal 200, response.code
    end
  end

  def test_parse_tables_info
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.class::LIST.each do |offence, _values|
      notebook_crawl.instance_variable_set(:@offence, offence)
      response = notebook_crawl.get_request("#{notebook_crawl.class::BASE_URL}#{offence}",
                                            {})
      parsed_info = notebook_crawl.parse_tables_info(response)
      assert_the_data(parsed_info, offence)
    end
  end

  def assert_the_data(parsed_info, offence)
    assert_true assert_general_info(parsed_info)
    case offence
    when 'List_of_Summary_Conviction_Offences'
      assert_true assert_summary_conviction(parsed_info)
    when 'List_of_Straight_Indictable_Offences'
      assert_true assert_straight_indictable(parsed_info)
    when 'List_of_Hybrid_Offences'
      assert_true assert_hybrid_offences(parsed_info)
    end
  end

  def assert_general_info(parsed_info)
    parsed_info.all? do |h|
      h.key?(:offence) && h.key?(:section)
    end
  end

  def assert_summary_conviction(parsed_info)
    parsed_info.all? do |h|
      h.key?(:maximum_fine) && h.key?(:minimums) && h.key?(:consecutive_time)
    end
  end

  def assert_straight_indictable(parsed_info)
    parsed_info.all? do |h|
      h.key?(:minimums) && h.key?(:mandatory_consecutive_time)
    end
  end

  def assert_hybrid_offences(parsed_info)
    parsed_info.all? do |h|
      h.key?(:minimums) && h.key?(:summary_election_maximum) && h.key?(:consecutive_time)
    end
  end
end
