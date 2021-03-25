#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (c) 2021 Samuel Y. Ayele
require 'json'
require 'addressable'
require 'rest-client'
require 'byebug'
require 'nokogiri'
require 'csv'
require 'down'
require 'fileutils'
# ------------------------------------------------------------------------------
class CapCrawl
  LETTERS = %w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z).freeze

  BASE_URL = 'https://laws-lois.justice.gc.ca/'
  ACTS_URL = 'eng/acts/'

  def crawl
    all_acts = []
    create_folders
    LETTERS.each do |index|
      index_acts = []
      create_index_folders(index)
      begin
        response = get_request("#{BASE_URL}#{ACTS_URL}#{index}.html", {})
      rescue RestClient::ExceptionWithResponse => e
        display_error(e, "#{BASE_URL}#{ACTS_URL}#{index}.html")
      end
      targeted_acts_content = target_acts_content(response)
      act_details = extract_acts_details(targeted_acts_content, index_acts, index)
      all_acts << act_details
      write_one_to_file(index_acts, index, act_details)
    end
    write_all_to_file(all_acts)
  end

  def extract_acts_details(targeted_acts_content, index_acts, _index)
    act_details = {}
    targeted_acts_content.children.each do |act|
      next if act.children.count < 1

      act_details = get_details(act)
      index_acts << act_details
    end
    act_details
  end

  def target_acts_content(response)
    Nokogiri::HTML(response).css('.wet-boew-zebra')
  end

  def create_folders
    Process.spawn('mkdir PDFs && mkdir JSONs && mkdir HTMLs')
    # Process.spawn("mkdir XMLs")
  end

  def create_index_folders(index)
    Process.spawn("mkdir PDFs/#{index} && mkdir JSONs/#{index} && mkdir HTMLs/#{index}")
    # Process.spawn("mkdir XMLs/#{index}")
  end

  def write_all_to_file(all_acts)
    File.write('JSONs/all_parliament_acts.json',
               JSON.dump(all_acts))
  end

  def write_one_to_file(index_acts, index, act_details)
    get_pdf_file(act_details[:uri], index)
    get_html_file(act_details, index)
    # get_xml_file(act_details, index)
    File.write("JSONs/#{index}/#{index}_parliament_acts.json",
               JSON.dump(index_acts))
    display_message(act_details, 'notice')
  end

  def get_details(act)
    act_details = {}
    act_details[:name] = act.children[0].content.strip
    cyc_details = get_cyc_details(act)
    more_details = get_more_details(act)

    act_details[:uri] = act.css('a').attribute('href').value.to_s
    act_details = act_details.merge(cyc_details)
    act_details = act_details.merge(more_details)
    display_message(act_details, 'status')
    act_details
  end

  def display_message(act_details, flag)
    puts "[Notice][CAP] Finished processing ... #{act_details[:name]}" if flag == 'notice'
    puts "[Status][CAP] Processing #{act_details[:name]} now..." if flag == 'status'
  end

  def display_error(error, url)
    puts "[Error][CAP] - #{error} for #{url}"
  end

  def get_pdf_file(uri, index)
    Down.download("#{BASE_URL}PDF/#{uri.split('/')[0]}.pdf", destination: 'PDFs')
    Process.spawn("mv PDFs/down\*.pdf PDFs/#{index}/#{uri.split('/')[0]}.pdf")
  end

  def get_html_file(act_details, index)
    Down.download("#{BASE_URL}#{ACTS_URL}#{act_details[:uri].split('/')[0]}/FullText.html",
                  destination: 'HTMLs/')
    Process.spawn("mv HTMLs/down\*.html HTMLs/#{index}/#{act_details[:uri].split('/')[0]}.html")
  end

  def get_cyc_details(act)
    cyc_details = { category: '', year: '', code: '' }
    return cyc_details unless act.text[/\d\d\d\d/]

    if act.children.count < 5
      target_content2 = act.children[2].content.strip
      extract_details(target_content2, cyc_details)
    else
      target_content4 = act.children[4].content.strip
      extract_details(target_content4, cyc_details)
    end
    cyc_details
  end

  def extract_details(content, cyc_details)
    if content.split(',').count < 3
      # S.C. 1979, c. 7, S.C. 1979, c. 7,  R.S.C. 1979, c. 7 (sometimes
      # S.C. 1963, c. 6
      extract_one_comma_coding(cyc_details, content)
    else
      # R.S.C., 1979, c. 7, S.C., 1979, c. 7
      extract_two_comma_coding(cyc_details, content)
      cyc_details
    end
  end

  def extract_one_comma_coding(cyc_details, content)
    # S.C. 1979, c. 7, S.C. 1979, c. 7,  R.S.C. 1979, c. 7 (sometimes)
    content = content[/\n.+/].strip
    cyc_details[:year] = content[/\d\d\d\d+/] # eg. 1979
    cyc_details[:category] = content[/S\.C\.|R\.S\.C\./] # eg. R.S.C. or S.C.
    cyc_details[:code] = content.strip.split(',')[1].strip # eg. c. A-5, A-14
  end

  def extract_two_comma_coding(cyc_details, content)
    content = content[/\n.+/].strip
    cyc_details[:year] = content[/\d\d\d\d+/] # eg. 1979
    cyc_details[:category] = content[/S\.C\.|R\.S\.C\./] # eg. R.S.C. or S.C.
    splitted_details = content.split(',')
    cyc_details[:code] =
      if splitted_details[0][/\d\d\d\d/]
        content.split(',')[1..2].join(',').strip
      else
        content.split(',')[2].strip # eg. c. A-5, A-14
      end
  end

  def get_more_details(act)
    more_details = { has_regulations: false, repealed: false }
    more_details[:has_regulations] = true if act.children[2].content
                                                .strip == 'R'
    more_details[:repealed] = true if act.children[0].content.strip[/Repealed/]
    more_details
  end

  def get_request(url, headers)
    RestClient::Request.execute(method:  :get,
                                url:     Addressable::URI.parse(url)
                                           .normalize.to_str,
                                headers: headers,
                                timeout: 50)
  end
end

# bc_cap_crawler = CapCrawl.new
# bc_cap_crawler.crawl
