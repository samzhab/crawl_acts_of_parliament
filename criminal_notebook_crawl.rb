# Important notes
# Make sure to create directories TEXTs/criminalnotebook and JSONs/criminalnotebook within the root
# !/usr/bin/env ruby
require "json"
require "addressable"
require "rest-client"
require "byebug"
require "nokogiri"
require "csv"
require "down"
require "webmock"
require "fileutils"
require "progressbar"

class CriminalNoteBookCrawl
  BASE_URL = "http://criminalnotebook.ca/index.php/".freeze
  # This include the list of offences that we are intereseted in
  # I believe this is is incomplete.Searching summary conviction within the page opened we get more results than listed
  # The below script uses keywords for extraction.
  LIST = {
    "List_of_Summary_Conviction_Offences" => ["summary conviction"], "List_of_Straight_Indictable_Offences" => ["indictable offence"],
    "List_of_Hybrid_Offences" => ["hybrid"]
  }.freeze
  JSON_PATH = "JSONs/criminalnotebook".freeze
  TEXT_PATH = "TEXTs/criminalnotebook".freeze

  def start
    progressbar = ProgressBar.create(title: "Offences", starting_at: 0, total: LIST.count)
    LIST.each do |offence, values|
      create_folders(offence)
      begin
        response = get_request("#{BASE_URL}#{offence}", {})
      rescue RestClient::ExceptionWithResponse => e
        puts "Failed #{e}"
      end
      tables_info = parse_tables_info(response)
      write_json_to_file(offence, tables_info)
      fetch_full_detail(offence, values)
      progressbar.increment
    end
    progressbar.finish
  end

  def fetch_full_detail(offence, values)
    read_data_from_file("#{JSON_PATH}/#{offence}/#{offence}.json").each do |dat|
      begin
        response = get_request("#{BASE_URL}#{dat["url"]}", {})
      rescue RestClient::ExceptionWithResponse => e
        puts "Failed #{e}"
      end
      text_to_write = []
      Nokogiri::HTML(response).css("blockquote").each do |blockquote|
        (text_to_write << blockquote.text) if extract_offence_from_html(values, blockquote)
      end
      write_text_to_file(text_to_write, dat["url"], offence)
    end
  end

  private

  # This will write the data from table in the format
  # {:offence=><data_from_table>, section=><as_listed_in_table, :url=><url_in_the_hyperlink>}.
  # For each element in the LIST it create folders with files in it.
  def write_json_to_file(offence, tables_info)
    File.write("#{JSON_PATH}/#{offence}/#{offence}.json", JSON.dump(tables_info))
  end

  # This will write text file with offences matching the listed values in the LIST hash
  def write_text_to_file(text_to_write, url, offence)
    File.open("#{TEXT_PATH}/#{offence}/#{url}.txt", "w+") do |f|
      text_to_write.each {|element| f.puts(element.to_s) }
    end
  end

  def parse_tables_info(response)
    tables_info = []
    Nokogiri::HTML(response).css("table.wikitable").each do |table|
      tables_info << process_table(table)
      tables_info.flatten!
    end
    tables_info
  end

  def process_table(table)
    details_array = []
    table.css("td[1]").zip(table.css("td[2]")).each do |td, td2|
      detail_hash = {offence: td.text.gsub("\n","").strip, section: td2.text}
      td.css("a").each do |a|
        a_href = a['href'].gsub("/index.php/","").strip
        detail_hash[:url] = a_href
      end
      details_array << detail_hash
    end
    details_array
  end

  def read_data_from_file(path)
    file = File.read(path)
    JSON.parse(file)
  end

  def extract_offence_from_html(values, blockquote)
    values.map {|value| blockquote.text.include?(value.to_s) }.uniq.all? {|elem| elem == true }
  end

  def create_folders(offence)
    Process.spawn("mkdir #{JSON_PATH}/#{offence}")
    Process.spawn("mkdir #{TEXT_PATH}/#{offence}")
  end

  def get_request(url, headers)
    response = RestClient::Request.execute(
      method: :get,
      url: Addressable::URI.parse(url).normalize.to_str,
      headers: headers, timeout: 50
    )
    response
  end
end

notebook_crawl = CriminalNoteBookCrawl.new
notebook_crawl.start
