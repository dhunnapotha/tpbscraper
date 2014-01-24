require 'nokogiri'
require 'open-uri'
require 'debugger'
require 'json'
require File.dirname(__FILE__) + '/helpers.rb'
require File.dirname(__FILE__) + '/gmail_send.rb'

# TODO: A space in the search string leads to problems! Need to fix it
def sanity_check(config_file,torrent_names_file)
  # TODO: Remove the GC prefixes!
  if !ENV['GC_GMAIL_USERNAME'] || !ENV['GC_GMAIL_PASSWORD'] || !ENV['GC_GMAIL_DOMAIN']
    # TODO: Show proper help here
    error_log "GMAIL details not set! Aborting!!"
    abort
  end
  if !File.exists?(config_file)
    error_log "URL configuration file doesnot exist"
    abort
  end

  if !File.exists? torrent_names_file
    info_log "Files txt doesnot exist. Creating one now!" 
    File.open(torrent_names_file,"w") {}
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

def parse_tpb_url(url)
  doc = Nokogiri::HTML(open(url))
  # Search for nodes by css
  torrent_names = doc.css('.detLink').map { |e| e.content }
  torrent_magnets = doc.css("a[title='Download this torrent using magnet']").map { |e| e['href'] }
  Hash[torrent_names.zip torrent_magnets]
end

def read_file_content(file_name)
  file_content = File.open(file_name, 'r') { |f| f.read }
  file_content = file_content.chomp if file_content
  return file_content
end

def write_file_content(file_name,content)
  File.open(file_name, 'a') { |f| f.write(content) }
end

def curr_ts
  Time.now.strftime('%Y_%m_%d-%H_%M_%S')
end

def new_torrents_added?(file_content_to_write)
  !file_content_to_write.empty?
end

# Get a Nokogiri::HTML::Document for the page we’re interested in...
torrent_names_file = File.dirname(__FILE__) + "/torrent_names.txt"
config_file = File.dirname(__FILE__) + "/tpb_config.json"
sleep_time = 1800
category_wrapper = "\n<<--------------------------------\n"

sanity_check config_file,torrent_names_file
categories = build_crawler_urls(config_file)

# TODO: See where this goes
mail_content_to_send = ""

# infinte loop which goes to sleep every 30 mins
while true
  file_content_to_write = ""
  mail_content_to_send = ""

  f_content = read_file_content(torrent_names_file)
  
  categories.each do |cat_name,cat_url|
    torrents = parse_tpb_url(cat_url)
    torrents.each do |name,magnet_uri|
      next if f_content.include? name
      mail_content_to_send << "#{name} -> #{magnet_uri}\n\n"
      file_content_to_write << "#{name}\n"
    end
    mail_content_to_send << category_wrapper
  end

  new_updates = new_torrents_added?(file_content_to_write)
  # Send the new list of files
  if new_updates
    send_mail_from_gmail_smtp(ENV['GC_GMAIL_USERNAME'],ENV['GC_GMAIL_USERNAME'],"TPB Torrents Crawler #{curr_ts}",mail_content_to_send)
    # Save the files
    write_file_content(torrent_names_file,file_content_to_write)
  else
    info_log "No new updates!"
  end
  info_log "Taking a power nap for #{sleep_time/60.0} mins :-)"
  sleep(sleep_time)
end
