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
# require "webmock"
require 'fileutils'
# url = "#{base_url}#{acts_uri}Y.html"

# include WebMock::API
# WebMock.enable!
# ------------------------------------------------------------------------------
class CapCrawl
  LETTERS = %w(A B C D E F G H I J K
               L M N O P Q R S T U V W X Y Z).freeze

  BASE_URL = 'https://laws-lois.justice.gc.ca/'
  ACTS_URL = 'eng/acts/'

  def start
    all_acts = []
    LETTERS.each do |index|
      index_acts = []
      create_folders(index)
      begin
        response = get_request("#{BASE_URL}#{ACTS_URL}#{index}.html", {})
      rescue RestClient::ExceptionWithResponse => e
        display_error(e, "#{BASE_URL}#{ACTS_URL}#{index}.html")
      end
      Nokogiri::HTML(response).css('.wet-boew-zebra').children.each do |act|
        next if act.children.count < 1

        act_details = get_details(act)
        index_acts << act_details
        all_acts << act_details
        write_one_to_file(index_acts, index, act_details)
      end
    end
    write_all_to_file(all_acts)
  end

  def create_folders(index)
    Process.spawn("mkdir PDFs/#{index}")
    Process.spawn("mkdir JSONs/#{index}")
    Process.spawn("mkdir HTMLs/#{index}")
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
    case flag
    when 'notice'
      puts "[Notice][CAP] Finished processing ... #{act_details[:name]}"
    when 'status'
      puts "[Status][CAP] Processing #{act_details[:name]} now..."
    end
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

  # def get_xml_file(act_details, index)
  #   Down.download("#{BASE_URL}/eng/XML/#{act_details[:uri].split('/')[0]}.xml",
  #                 destination: "XMLs/")
  #   Process.spawn("mv XMLs/down\*.xml XMLs/#{index}/#{act_details[:uri].split('/')[0]}.xml")
  # end

  def get_cyc_details(act)
    cyc_details = { category: '', year: '', code: '' }
    target_content2 = act.children[2].content.strip
    target_content4 = act.children[4].content.strip
    return cyc_details unless target_content2[/\d+/] || target_content4[/\d+/]

    if act.children.count < 5
      extract_details(target_content2, cyc_details)
    else
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
    cyc_details[:code] = content.strip.split(',')[1].strip # eg. c. A-5, A-14
    cyc_details[:category] = content.split[3].strip # eg. R.S.C. or S.C.
    cyc_details[:year] = content.split[4][/[0-9]+/] # eg. 1979
  end

  def extract_two_comma_coding(cyc_details, content)
    # R.S.C., 1979, c. 7
    cyc_details[:category] = content.strip.split(',')[0].split("\n")[1]
    cyc_details[:year] = content.strip.split(',')[1].strip # 2017, 2014
    cyc_details[:code] = content.strip.split(',')[2].strip # eg. c. A-5, A-14
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

cap_crawl = CapCrawl.new
cap_crawl.start
