require 'nokogiri'
require 'open-uri'
require 'debugger'
require File.dirname(__FILE__) + '/helpers.rb'
require File.dirname(__FILE__) + '/gmail_send.rb'

def sanity_check
  if !ENV['GC_GMAIL_USER_NAME'] || !ENV['GC_GMAIL_PASSWORD'] || !ENV['GC_GMAIL_DOMAIN']
    error_log "GMAIL details not set! Aborting!!"
    abort
  end
end

# Get a Nokogiri::HTML::Document for the page we’re interested in...
url = 'http://thepiratebay.se/top/207'
torrent_names_file = File.dirname(__FILE__) + "/torrent_names.txt"

while true
  doc = Nokogiri::HTML(open(url))
  # sanity check
  sanity_check

  if !File.exists? torrent_names_file
    info_log "Files txt doesnot exist. Continuing Anyway!" 
    File.open(torrent_names_file,"w") {}
  end

  f = File.open(torrent_names_file,"a+")
  f_content = f.read


  # Search for nodes by css
  torrent_names = doc.css('.detLink')
  torrent_magnets = doc.css("a[title='Download this torrent using magnet']")

  mail_content = ""


  h = Hash[torrent_names.zip torrent_magnets]
  h.each do |key,value|
    needle = "#{key.content} -> #{value['href']}\n"
    #TODO: Calling readlines multiple times. Instead read the file once
    if !f_content.include? needle
      # Send a mail and append to the end of the torrrent names
      info_log "New torrent #{key.content}"
      mail_content << needle
      f.write("#{needle}")
    end
  end

  # Close the file
  f.close
  # Send the new list of files
  send_mail_from_gmail_smtp(ENV['GC_GMAIL_USERNAME'],ENV['GC_GMAIL_USERNAME'],"New torrent added",mail_content) unless mail_content.empty?

  info_log "Going to sleep! Will awake after 30 mins"
  sleep(1800)
end




