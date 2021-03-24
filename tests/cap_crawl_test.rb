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

require_relative '../libs/cap_crawl'

include WebMock::API
WebMock.enable!
class CapCrawlTest < Test::Unit::TestCase
  LETTERS = %w(A B C D E F G H I J K
               L M N O P Q R S T U V W X Y Z).freeze
  BASE_URL = 'https://laws-lois.justice.gc.ca/'
  ACTS_URL = 'eng/acts/'
  LETTERS.each do |index|
    url = "#{BASE_URL}#{ACTS_URL}#{index}.html"
    body = File.read("webmocks/#{index}.html")
    # ------------------------------------------------------stub requests
    stub_request(:get, url)
      .with(headers: { 'Accept'          => '*/*',
                       'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                       'Host'            => 'laws-lois.justice.gc.ca',
                       'User-Agent'      => 'rest-client/2.1.0 (linux x86_64) ruby/3.0.0p0' })
      .to_return(status: 200, body: body, headers: {})
  end

  def test_get_request
    crawler = CapCrawl.new

    url = 'https://laws-lois.justice.gc.ca/eng/acts/I.html'
    response = crawler.get_request(url, {})
    assert_equal 200, response.code

    url = 'https://laws-lois.justice.gc.ca/eng/acts/U.html'
    response = crawler.get_request(url, {})
    assert_equal 200, response.code

    url = 'https://laws-lois.justice.gc.ca/eng/acts/Z.html'
    response = crawler.get_request(url, {})
    assert_equal 200, response.code
  end

  def test_target_acts_content
    crawler = CapCrawl.new
    url = 'https://laws-lois.justice.gc.ca/eng/acts/H.html'
    response = crawler.get_request(url, {})
    targeted_acts_content = crawler.target_acts_content(response)
    assert_not_nil targeted_acts_content.children
    assert_not_empty targeted_acts_content
    assert_true targeted_acts_content.children.count > 1
    assert_equal targeted_acts_content.children.count, 33
  end

  def test_create_folders
    crawler = CapCrawl.new
    crawler.create_folders
    assert_path_exist('JSONs')
    assert_path_exist('HTMLs')
    assert_path_exist('PDFs')
  end

  def test_create_index_folders
    crawler = CapCrawl.new
    crawler.create_index_folders('R')
    assert_path_exist('JSONs/R')
    assert_path_exist('HTMLs/R')
    assert_path_exist('PDFs/R')
  end

  def test_extract_acts_details
    crawler = CapCrawl.new
    url = 'https://laws-lois.justice.gc.ca/eng/acts/S.html'
    response = crawler.get_request(url, {})
    targeted_acts_content = crawler.target_acts_content(response)
    act_details = crawler.extract_acts_details(targeted_acts_content, [], 'S')

    assert_true act_details.is_a? Hash
    assert_not_nil act_details
    assert_not_empty act_details
  end

  def test_extract_acts_details_keys
    crawler = CapCrawl.new
    url = 'https://laws-lois.justice.gc.ca/eng/acts/S.html'
    response = crawler.get_request(url, {})
    targeted_acts_content = crawler.target_acts_content(response)
    act_details = crawler.extract_acts_details(targeted_acts_content, [], 'S')

    assert_true act_details.key? :name
    assert_true act_details.key? :uri
    assert_true act_details.key? :category
    assert_true act_details.key? :code
    assert_true act_details.key? :has_regulations
    assert_true act_details.key? :repealed
  end

  def test_write_one_to_file
    # crawler = CapCrawl.new
    # url = "https://laws-lois.justice.gc.ca/eng/acts/H.html"
    # response = crawler.get_request(url,{})
    # targeted_acts_content = crawler.target_acts_content(response)
    # index_act_details = crawler.extract_acts_details(targeted_acts_content,'S')
    # assert_not_nil index_act_details.children
    # assert_not_empty index_act_details
    # assert_true index_act_details.children.count > 1
    # assert_equal index_act_details.children.count, 33
  end

  def test_write_all_to_file
    # crawler = CapCrawl.new
    # url = "https://laws-lois.justice.gc.ca/eng/acts/H.html"
    # response = crawler.get_request(url,{})
    # targeted_acts_content = crawler.target_acts_content(response)
    # extract_acts_details(target_acts_content,'S')
  end

  def test_display_message
    # crawler = CapCrawl.new
    # url = "https://laws-lois.justice.gc.ca/eng/acts/H.html"
    # response = crawler.get_request(url,{})
    # targeted_acts_content = crawler.target_acts_content(response)
    # extract_acts_details(target_acts_content,'S')
  end

  def test_extract_one_comma_coding
    # crawler = CapCrawl.new
    # url = "https://laws-lois.justice.gc.ca/eng/acts/H.html"
    # response = crawler.get_request(url,{})
    #   assert_equal 'world', cap_crawl.world, "Hello.world should return a string called 'world'"
  end

  def test_extract_two_comma_coding
    # crawler = CapCrawl.new
    # url = "https://laws-lois.justice.gc.ca/eng/acts/H.html"
    # response = crawler.get_request(url,{})
    #   assert_equal 'world', cap_crawl.world, "Hello.world should return a string called 'world'"
  end

  def test_get_more_details
    # crawler = CapCrawl.new
    # url = "https://laws-lois.justice.gc.ca/eng/acts/H.html"
    # response = crawler.get_request(url,{})
    #   assert_equal 'world', cap_crawl.world, "Hello.world should return a string called 'world'"
  end
end
