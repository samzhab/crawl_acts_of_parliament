## crawl Acts of Parliament Canada - Ruby

![temporary logo](https://bt-strike.s3-us-west-2.amazonaws.com/images/ruby.gif 'bt-strike temporary logo')

A simple ruby script to be used for a later project as a library to acquire consolidated acts of Parliament in Canada, serialize it to JSON and get all the pdf to store locally.

Prerequisites:

- rvm (rvm.io)
- ruby interpreter (3.0.0)
- required gems (see Gemfile)
- linux terminal

Webmock and Stubbing http requests:

- you can stub your http requests using webmock for testing
- run the bash script `$ ./curl_get_stubs.sh`
- add following lines begining of 'LETTERS' loop `body = File.read("webmocks/#{index}.html")`
- read your files with `body = File.read("webmocks/#{index}.html")`
- stub your http requests (add next to previous line)
  `stub_request(:get, url). with(headers: { 'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'laws-lois.justice.gc.ca', 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/3.0.0p0' }).to_return(status: 200, body: body, headers: {}) `

Features to add [coming soon...]

- extract other relevant information such as last updated and date of ascentamong others

Setup usage with rvm and process event series:

- get latest ruby interpreter
  `$ rvm install ruby`a
- create a gemset
  `$ rvm gemset create <gemset>`
  eg. `$ rvm gemset create person_doesnot_exist`
- use created gemset
  `$ rvm <ruby version>@<gemset>`
- install bundler gem
  `$ gem install bundler`
- install necessary gems
  `$ bundle`
- create folder 'persons' for articles saved as pdf
  `$ mkdir persons`
- make script executable
  `$ chmod +x <script_name.rb>`
- run script
  `$ ./<script_name.rb>`

Further Development [coming soon...]

- Task 1 -
- Task 1-1 -

To run the test for criminal_notebook_crawl

1. Run `$ ./curl_get_stubs_for_notebook.sh`
2. From root directory
   `$ ruby tests/criminal_notebook_crawl_test.rb`

To run the test for generate_timeline

1. From root directory
   `$ ruby tests/generate_timeline_test.rb`

[![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

This work is licensed under a
[Creative Commons Attribution-NonCommercialShareAlike 4.0 International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg
