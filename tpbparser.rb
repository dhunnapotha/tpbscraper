require 'nokogiri'
require 'open-uri'
require 'debugger'
require 'json'
require File.dirname(__FILE__) + '/helpers.rb'
require File.dirname(__FILE__) + '/gmail_send.rb'

# TODO: A space in the search string leads to problems! Need to fix it
def sanity_check(config_file)
  if !ENV['GC_GMAIL_USERNAME'] || !ENV['GC_GMAIL_PASSWORD'] || !ENV['GC_GMAIL_DOMAIN']
    error_log "GMAIL details not set! Aborting!!"
    abort
  end
  if !File.exists?(config_file)
    error_log "URL configuration file doesnot exist"
    abort
  end

  # TODO: Check if the domain is reachable!
end


# urls will have ke
def build_crawler_urls(config_file)
  config = JSON.parse(IO.read(config_file))
  domain = config['domain']
  base_uri = "http://#{domain}"
  categories = Hash.new 

  # Collect all the top categories
  if config.has_key? 'top100'
    config['top100'].each do |name,num|
      categories[name] = "#{base_uri}/top/#{num}"
    end
  end

  # Collect all the search categories
  if config.has_key? "search"
    config['search'].each do |name|
      categories[name] = "#{base_uri}/search/#{name}/0/7/0"
    end
  end
  return categories
end

# Get a Nokogiri::HTML::Document for the page we’re interested in...
torrent_names_file = File.dirname(__FILE__) + "/torrent_names.txt"
config_file = File.dirname(__FILE__) + "/tpb_config.json"

sanity_check config_file

categories = build_crawler_urls(config_file)

if !File.exists? torrent_names_file
  info_log "Files txt doesnot exist. Creating one now!" 
  File.open(torrent_names_file,"w") {}
end

mail_content = ""
f = File.open(torrent_names_file,"a+")
f_content = f.read
while true
  categories.each do |name,url|
    doc = Nokogiri::HTML(open(url))
    # sanity check

    # TODO: This can be moved out of the loop

    # Search for nodes by css
    torrent_names = doc.css('.detLink')
    torrent_magnets = doc.css("a[title='Download this torrent using magnet']")

    mail_content << "\n--------------#{name}------------------\n"

    h = Hash[torrent_names.zip torrent_magnets]
    h.each do |key,value|
      needle = "#{key.content}"
      #TODO: Calling readlines multiple times. Instead read the file once
      if !f_content.include? needle
        # Send a mail and append to the end of the torrrent names
        info_log "New torrent #{key.content}"
        # If possible, write HTML content to the mail!
        mail_content << "#{needle} -> #{value['href']}\n"
        f.write("#{needle}\n")
      end
    end
    mail_content << "\n--------------#{name}------------------\n"
  end
  
  # Close the file
  f.close
  # Send the new list of files
  send_mail_from_gmail_smtp(ENV['GC_GMAIL_USERNAME'],ENV['GC_GMAIL_USERNAME'],"New torrents added",mail_content) unless mail_content.empty?

  info_log "Going to sleep! Will awake after 30 mins"
  sleep(1800)
end
