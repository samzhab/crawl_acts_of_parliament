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
    'List_of_Summary_Conviction_Offences'         => ['summary conviction'],
    'List_of_Straight_Indictable_Offences'        => ['indictable offence'],
    'List_of_Hybrid_Offences'                     => %w(hybrid),
    'Miscellaneous_Offences_Against_Public_Order' => %w()
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
      sleep 0.2
      assert_true Dir.exist?("#{notebook_crawl.class::JSON_PATH}/#{offence}")
      assert_true Dir.exist?("#{notebook_crawl.class::TEXT_PATH}/#{offence}")
    end
  end

  def test_get_request
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.class::LIST.each do |offence, _values|
      url = "#{notebook_crawl.class::BASE_URL}#{offence}"
      response = notebook_crawl.get_request(url, {})
      assert_equal 200, response.code
    end
  end

  def test_parse_tables_info_for_summary_offences
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.instance_variable_set(:@offence, 'List_of_Summary_Conviction_Offences')
    url = "#{notebook_crawl.class::BASE_URL}List_of_Summary_Conviction_Offences"
    response = notebook_crawl.get_request(url, {})
    assert_equal 200, response.code
    parsed_info = notebook_crawl.parse_tables_info(response)
    assert_true(parsed_info.all? do |h|
                  h.key?(:offence) &&
                    h.key?(:section) &&
                    h.key?(:maximum_fine) &&
                    h.key?(:minimums) &&
                    h.key?(:consecutive_time)
                end)
  end

  def test_parse_tables_info_for_indictable_offences
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.instance_variable_set(:@offence, 'List_of_Straight_Indictable_Offences')
    url = "#{notebook_crawl.class::BASE_URL}List_of_Straight_Indictable_Offences"
    response = notebook_crawl.get_request(url, {})
    assert_equal 200, response.code
    parsed_info = notebook_crawl.parse_tables_info(response)
    assert_true(parsed_info.all? do |h|
                  h.key?(:offence) &&
                    h.key?(:section) &&
                    h.key?(:minimums) &&
                    h.key?(:mandatory_consecutive_time)
                end)
  end

  def test_parse_tables_info_for_hybrid_offences
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.instance_variable_set(:@offence, 'List_of_Hybrid_Offences')
    url = "#{notebook_crawl.class::BASE_URL}List_of_Hybrid_Offences"
    response = notebook_crawl.get_request(url, {})
    assert_equal 200, response.code
    parsed_info = notebook_crawl.parse_tables_info(response)
    assert_true(parsed_info.all? do |h|
                  h.key?(:offence) &&
                    h.key?(:section) &&
                    h.key?(:minimums) &&
                    h.key?(:summary_election_maximum) &&
                    h.key?(:consecutive_time)
                end)
  end

  def test_parse_blockquote
    sample_url = "#{BASE_URL}Miscellaneous_Offences_Against_Public_Order"
    notebook_crawl = CriminalNoteBookCrawl.new
    response = notebook_crawl.get_request(sample_url, {})
    assert_equal 200, response.code
    values = ['summary conviction']
    text_parsed = notebook_crawl.parse_blockquote(response, ['summary conviction'])
    text_parsed.flatten.each do |text|
      assert_false !values.all? { |val| text.downcase.include?(val) }
    end
  end

  def test_headings_for_tables
    notebook_crawl = CriminalNoteBookCrawl.new
    response = notebook_crawl.get_request("#{BASE_URL}List_of_Summary_Conviction_Offences", {})
    headings_for_tables = notebook_crawl.headings_for_tables(response)
    assert_true headings_for_tables.is_a?(Array)
    assert_true headings_for_tables.count.positive?
  end

  def test_process_table
    notebook_crawl = CriminalNoteBookCrawl.new
    response = notebook_crawl.get_request("#{BASE_URL}List_of_Summary_Conviction_Offences", {})
    heading = 'Maximum Punishment is Imprisonment for 2 Years Less a Day (summary conviction)'
    table_info = notebook_crawl.process_table(Nokogiri::HTML(response).css('table.wikitable').first,
                                              heading)
    assert_true(table_info.all? do |h|
      h[:punishment] == heading
    end)
  end

  def test_parse_from_column
    notebook_crawl = CriminalNoteBookCrawl.new
    response = notebook_crawl.get_request("#{BASE_URL}List_of_Summary_Conviction_Offences", {})
    td_column = Nokogiri::HTML(response).css('table.wikitable').first.css('td[1]').first
    column_data = notebook_crawl.parse_from_column(td_column)
    assert_true column_data == 'Miscellaneous_Offences_Against_Public_Order'
  end

  def test_fetch_based_on_offence
    notebook_crawl = CriminalNoteBookCrawl.new
    notebook_crawl.instance_variable_set(:@offence, 'List_of_Summary_Conviction_Offences')
    response = notebook_crawl.get_request("#{BASE_URL}List_of_Summary_Conviction_Offences", {})
    table = Nokogiri::HTML(response).css('table.wikitable').first
    td_column_first = table.css('td[3]').zip(table.css('td[4]'),
                                             table.css('td[5]')).first
    method_keys = notebook_crawl.fetch_based_on_offence(td_column_first[0],
                                                        td_column_first[1],
                                                        td_column_first[2]).keys
    assert_true method_keys == %i(maximum_fine minimums consecutive_time)
  end

  def test_key_infos
    notebook_crawl = CriminalNoteBookCrawl.new
    response = notebook_crawl.get_request("#{BASE_URL}List_of_Summary_Conviction_Offences", {})
    table = Nokogiri::HTML(response).css('table.wikitable').first
    td_column_first = table.css('td[3]').zip(table.css('td[4]'),
                                             table.css('td[5]')).first
    string_array = notebook_crawl.key_infos([td_column_first[0], td_column_first[1]])
    assert_true string_array.is_a?(Array)
  end

  def test_extract_offence_from_html
    notebook_crawl = CriminalNoteBookCrawl.new
    response = notebook_crawl.get_request(
      "#{BASE_URL}Miscellaneous_Offences_Against_Public_Order", {}
    )
    blockquote = Nokogiri::HTML(response).css('blockquote').first.text
    value_exist = notebook_crawl.extract_offence_from_html(['summary conviction'], blockquote)
    assert_true !!value_exist == value_exist
  end

  def test_beutify_string
    notebook_crawl = CriminalNoteBookCrawl.new
    returned_string = notebook_crawl.beutify_string("\nHello")
    assert_true !returned_string.include?("\n")
  end

  # fill out these tests please >>>>

  # def test_read_data_from_file

  # end

  # def test_fetch_full_detail

  # end

  # def test_parse_blockquote

  # end

  # def test_headings_for_tables

  # end

  # def test_parse_tables_info

  # end

  # def test_process_table

  # end

  # def test_parse_from_column

  # end

  # def test_fetch_based_on_offence

  # end

  # def test_data_for_indictable

  # end

  # def test_data_for_hybrid

  # end

  # def test_key_infos

  # end

  # def test_extract_offence_from_html

  # end
end
