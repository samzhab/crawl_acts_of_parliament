#IMPORTANT NOTES
#Make sure to create directories TEXTs/criminalnotebook and JSONs/criminalnotebook within the root

#!/usr/bin/env ruby
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
  BASE_URL = 'http://criminalnotebook.ca/index.php/'.freeze
  #This include the list of offences that we are intereseted in. when accessing for eg: http://criminalnotebook.ca/index.php/List_of_Summary_Conviction_Offences the offences are listed in tables with a hyperlink to the definition. I believe the list of offences in the table is not complete. If we search for the keyword summary conviction within the page opened we get more results than listed in the table. Therefore the below script actually uses keywords for extraction offences.
  LIST = {
          'List_of_Summary_Conviction_Offences' => ['summary conviction'],
          'List_of_Straight_Indictable_Offences' => ['indictable offence'],
          'List_of_Hybrid_Offences' => ['hybrid']
  }.freeze
  JSON_PATH = "JSONs/criminalnotebook".freeze
  TEXT_PATH = "TEXTs/criminalnotebook".freeze

  def start
    progressbar = ProgressBar.create(:title => "Offences", :starting_at => 0, :total => LIST.count)
    LIST.each do |offence, values|
      create_folders(offence)
      begin
        response = get_request("#{BASE_URL}#{offence}", {})
      rescue RestClient::ExceptionWithResponse => e
        puts "Failed #{e}"
      end
      tables = Nokogiri::HTML(response).css('table.wikitable')
      tables_info = []
      tables.each do |table|
        tables_info << process_table(table)
        tables_info.flatten!
      end
      write_json_to_file(offence, tables_info)
      fetch_full_detail(offence, values)
      progressbar.increment
    end
    progressbar.finish
  end

  def fetch_full_detail(offence, values)
    file = File.read("#{JSON_PATH}/#{offence}/#{offence}.json")
    data_hash = JSON.parse(file)
    data_hash.each do |dat|
      begin
        response = get_request("#{BASE_URL}#{dat["url"]}", {})
      rescue RestClient::ExceptionWithResponse => e
        puts "Failed #{e}"
      end

      blockquotes = Nokogiri::HTML(response).css('blockquote')
      text_to_write = []
      blockquotes.each do |blockquote|
        extract_offence = values.map {|value| blockquote.text.include?(value.to_s) }.uniq.all? { |elem| elem == true }
        (text_to_write << blockquote.text) if extract_offence
      end
      write_text_to_file(text_to_write, dat["url"], offence)
    end
  end

  private
  #This will write the data from table in the format {:offence=><data_from_table>, section=><as_listed_in_table, :url=><url_in_the_hyperlink>}. For each element in the LIST it create folders with files in it.
  def write_json_to_file(offence, tables_info)
    File.write("#{JSON_PATH}/#{offence}/#{offence}.json",
      JSON.dump(tables_info))
  end

  #This will write text file with offences matching the listed values in the LIST hash
  def write_text_to_file(text_to_write, url, offence)
    File.open("#{TEXT_PATH}/#{offence}/#{url}.txt", "w+") do |f|
      text_to_write.each { |element| f.puts(element.to_s) }
    end
  end

  def process_table(table)
    details_array = []
    table.css('td[1]').zip(table.css('td[2]')).each do |td, td2|
      td_offence = td.text.gsub("\n","").strip
      td_section = td2.text
      detail_hash = {offence: td_offence, section: td_section}
      td.css('a').each do |a|
        a_href = a['href'].gsub("/index.php/","").strip
        detail_hash[:url] = a_href
      end
      details_array << detail_hash
    end
    details_array
  end

  def create_folders(offence)
    # Process.spawn("rm -rf #{JSON_PATH}/#{offence}")
    Process.spawn("mkdir #{JSON_PATH}/#{offence}")
    # Process.spawn("rm -rf #{TEXT_PATH}/#{offence}")
    Process.spawn("mkdir #{TEXT_PATH}/#{offence}")
  end

  def get_request(url, headers)
    response = RestClient::Request.execute(method: :get,
                                           url: Addressable::URI.parse(url)
                                           .normalize.to_str,
                                           headers: headers,
                                           timeout: 50)
    response
  end
end

notebook_crawl = CriminalNoteBookCrawl.new
notebook_crawl.start