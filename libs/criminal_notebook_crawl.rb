# Copyright (c) 2021 Abin Abraham
# frozen_string_literal: true

# !/usr/bin/env ruby
require 'json'
require 'addressable'
require 'rest-client'
require 'byebug'
require 'nokogiri'
require 'csv'
require 'down'
require 'webmock'
require 'fileutils'

module CrawlerHelper
  # This will write the data from table in the format
  # {:offence=><data_from_table>, section=><as_listed_in_table, :url=><url_in_the_hyperlink>}.
  # For each element in the LIST it create folders with files in it.
  def write_json_to_file(offence, tables_info)
    File.write("#{self.class::JSON_PATH}/#{offence}/#{offence}.json", JSON.dump(tables_info))
    grouped_data = tables_info.group_by { |h| h[:punishment] }
    File.write("#{self.class::JSON_PATH}/#{offence}/grouped_#{offence}.json",
               JSON.dump(grouped_data))
  end

  # This will write text file with offences matching the listed values in the LIST hash
  def write_text_to_file(text_to_write, url, offence)
    File.open("#{self.class::TEXT_PATH}/#{offence}/#{url}.txt", 'w+') do |f|
      text_to_write.each { |element| f.puts(element.to_s) }
    end
    File.open("#{self.class::TEXT_PATH}/#{offence}.txt", 'a') do |f|
      text_to_write.each { |element| f.puts(element.to_s) }
    end
  end

  def create_folders(offence)
    [self.class::JSON_PATH, self.class::TEXT_PATH].each do |path|
      if Dir.exist?(path.to_s)
        Process.spawn("rm -rf #{path}/#{offence}") if Dir.exist?("#{path}/#{offence}")
      else
        Process.spawn("mkdir #{path}")
      end
      sleep 0.2
      Process.spawn("mkdir #{path}/#{offence}")
    end
  end

  def read_data_from_file(path)
    file = File.read(path)
    JSON.parse(file)
  end

  def get_request(url, headers)
    RestClient::Request.execute(
      method: :get,
      url: Addressable::URI.parse(url).normalize.to_str,
      headers: headers, timeout: 50
    )
  end

  def display_message(message, flag)
    case flag
    when 'notice'
      puts "[Notice][CAP] Finished processing url ... #{self.class::BASE_URL}#{message}"
    when 'status'
      puts "[Status][CAP] Processing url #{self.class::BASE_URL}#{message} now..."
    end
  end
end

class CriminalNoteBookCrawl
  include CrawlerHelper
  BASE_URL = 'http://criminalnotebook.ca/index.php/'
  # This include the list of offences that we are intereseted in
  # I believe this is is incomplete.
  # Searching summary conviction within the page opened we get more results than listed
  # The below script uses keywords for extraction.
  LIST = {
    'List_of_Summary_Conviction_Offences'  => ['summary conviction'],
    'List_of_Straight_Indictable_Offences' => ['indictable offence'],
    'List_of_Hybrid_Offences'              => %w(hybrid)
  }.freeze
  JSON_PATH = 'JSONs/criminalnotebook'
  TEXT_PATH = 'TEXTs/criminalnotebook'

  def start
    LIST.each do |offence, values|
      @offence = offence
      create_folders(offence)
      begin
        response = get_request("#{BASE_URL}#{offence}", {})
      rescue RestClient::ExceptionWithResponse => e
        puts "Failed #{e}"
      end
      display_message(offence, 'status')
      tables_info = parse_tables_info(response)
      write_json_to_file(offence, tables_info)
      fetch_full_detail(offence, values)
      display_message(offence, 'notice')
    end
  end

  def fetch_full_detail(offence, values)
    used_urls = []
    read_data_from_file("#{JSON_PATH}/#{offence}/#{offence}.json").each do |dat|
      next if used_urls.include?(dat['url'])

      used_urls << dat['url']
      display_message(dat['url'], 'status')
      begin
        response = get_request("#{BASE_URL}#{dat['url']}", {})
      rescue RestClient::ExceptionWithResponse => e
        puts "Failed #{e}"
      end
      write_text_to_file(parse_blockquote(response, values), dat['url'], offence)
      display_message(dat['url'], 'notice')
    end
  end

  def parse_blockquote(response, values)
    text_to_write = []
    Nokogiri::HTML(response).css('blockquote').each do |blockquote|
      (text_to_write << blockquote.text) if extract_offence_from_html(values, blockquote.text)
    end
    text_to_write
  end

  def headings_for_tables(response)
    headings_for_tables = Nokogiri::HTML(response).css('.mw-headline').map(&:text)
    map_to_array = ['Previous', 'References', 'Previous', 'See Also', 'Previous Offences']
    headings_for_tables.each { |i| map_to_array.include?(i) }
    headings_for_tables
  end

  def parse_tables_info(response)
    tables_info = []
    headings_for_tables = headings_for_tables(response)
    dt_parser = Nokogiri::HTML(response).css('table.wikitable').zip(headings_for_tables)
    dt_parser.each do |table, heading|
      tables_info << process_table(table, heading)
      tables_info.flatten!
    end
    tables_info
  end

  def process_table(table, heading)
    details_array = []
    table.css('td[1]').zip(table.css('td[2]'),
                           table.css('td[3]'),
                           table.css('td[4]'),
                           table.css('td[5]')).each do |td1, td2, td3, td4, td5|
      detail_hash = fetch_based_on_offence(td1, td2, td3, td4, td5)
      detail_hash[:punishment] = heading
      detail_hash[:url] = parse_from_column(td1)
      details_array << detail_hash
    end
    details_array
  end

  def parse_from_column(td1)
    td1.css('a').map { |a| a['href'].split('/').last.split('#').first }.last
  end

  def fetch_based_on_offence(td1, td2, td3, td4, td5)
    general_data = { offence: td1.text.delete("\n").strip.gsub('From', ' From'),
                     section: td2.text.delete("\n").strip }

    case @offence
    when 'List_of_Summary_Conviction_Offences'
      data_for_summary(general_data, [td3, td4, td5])
    when 'List_of_Straight_Indictable_Offences'
      data_for_indictable(general_data, [td3, td4])
    when 'List_of_Hybrid_Offences'
      data_for_hybrid(general_data, [td3, td4, td5])
    else
      {}
    end
    general_data
  end

  def data_for_summary(general_data, cols)
    general_data[:maximum_fine],
    general_data[:minimums],
    general_data[:consecutive_time] = key_infos(cols)
  end

  def data_for_indictable(general_data, cols)
    general_data[:minimums],
    general_data[:mandatory_consecutive_time] = key_infos(cols)
  end

  def data_for_hybrid(general_data, cols)
    general_data[:minimums],
    general_data[:summary_election_maximum],
    general_data[:consecutive_time] = key_infos(cols)
  end

  def key_infos(cols)
    cols.map { |col| col.text.delete("\n").strip }
  end

  # This method can be used to extract data from blickquote based on conditions
  def extract_offence_from_html(values, blockquote_text)
    blockquote_text.gsub!(/[^0-9A-Za-z ]/, '')
    values.map { |value| blockquote_text.include?(value.to_s) }.uniq.all? { |elem| elem == true }
  end
end

# notebook_crawl = CriminalNoteBookCrawl.new
# notebook_crawl.start
