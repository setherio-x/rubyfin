#!/usr/bin/env ruby

require "json"
require "gum"
require "lipgloss"
require "ostruct"
require "net/http"
require "json"

CONFIG_PATH = File.join(Dir.home, ".config", "rubyfin", "config.json")

def setup_config
  url = Gum.input(placeholder: "http://localhost:8096", header: "Server URL")
  username = Gum.input(placeholder: "Enter your username", header: "Username")
  password = Gum.input(placeholder: "Enter your password", header: "Password", password: true)

  config = {
    "url" => url,
    "username" => username,
    "password" => password
  }

  config_dir = File.dirname(CONFIG_PATH)
  Dir.mkdir(config_dir) unless Dir.exist?(config_dir)

  File.write(CONFIG_PATH, JSON.pretty_generate(config))

  config
  
end

def check_connection(url)
  uri = URI("#{url}/System/Info/Public")
  response = Net::HTTP.get_response(uri)

  if response.is_a?(Net::HTTPSuccess)
    return true
  else
    return false
  end
end

def get_libraries
  uri = URI("#{SESSION.url}/Users/#{SESSION.uid}/Views")
  request = Net::HTTP::Get.new(uri)
  request["X-Emby-Authorization"] = HEADERS

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  data = JSON.parse(response.body)
  libraries = data["Items"]

  libraries
end
def select_libraries
  libraries = get_libraries
  names = libraries.map { |lib| lib["Name"] }
  choice = Gum.choose(names)
  selected = libraries.find { |lib| lib["Name"] == choice }
  selected["Id"]

end

def get_items(library_id)
  uri = URI("#{SESSION.url}/Users/#{SESSION.uid}/Items?ParentId=#{library_id}&Limit=10")
  request = Net::HTTP::Get.new(uri)
  request["X-Emby-Authorization"] = HEADERS

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  data = JSON.parse(response.body)
  items = data["Items"]

  items.each do |item|
    puts item["Name"]
  end

  items
end

def browse(library_id)
  current_id = library_id

  loop do
    items = get_items(current_id)

    if items.first && items.first["Type"] == "Episode"
      names = items.map { |ep| "#{ep['IndexNumber']}. #{ep['Name']}" }
      choice = Gum.choose(names)
      selected = items.find { |ep| "#{ep['IndexNumber']}. #{ep['Name']}" == choice }
      system("mpv", "#{SESSION.url}/Videos/#{selected['Id']}/stream?static=true&api_key=#{SESSION.token}")
      break
    end
    # Otherwise let user pick and go deeper
    names = items.map { |item| item["Name"] }
    choice = Gum.choose(names)
    selected = items.find { |item| item["Name"] == choice }
    current_id = selected["Id"]
  end
end

def get_user_info(config)
  url = config["url"]
  uri = URI("#{url}/Users/AuthenticateByName")

  request = Net::HTTP::Post.new(uri)
  request["Content-Type"] = "application/json"
  request["X-Emby-Authorization"] = 'MediaBrowser Client="Rubyfin", Device="PC", DeviceId="rubyfin", Version="0.1.0"'
  request.body = JSON.generate({
    "Username" => config["username"],
    "Pw" => config["password"]
  })

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(request)
  end

  data = JSON.parse(response.body)
  token = data["AccessToken"]
  uid = data["User"]["Id"]

  # puts "Token: #{access_token}"
  # puts "User ID: #{user_id}"
  return { "token" => token, "uid" => uid }
end


if File.exist?(CONFIG_PATH)
  config = JSON.parse(File.read(CONFIG_PATH))
else
  config = setup_config
end



unless check_connection(config["url"])
  puts "Unable to connect."
  exit
end

style = Lipgloss::Style.new
  .bold(true)
  .foreground("#50fa7b")
#  .border(:rounded)
#  .border_foreground("#874BFD")
  .padding(1, 2)
#  .width(60)

user_info = get_user_info(config)

# puts user_info["token"]
# puts user_info["uid"]

HEADERS = 'MediaBrowser Client="Rubyfin", Device="PC", DeviceId="rubyfin", Version="0.1.0", Token="' + user_info["token"] + '"'

# session: url, username, password, token, uid
SESSION = OpenStruct.new(config.merge(user_info))

library_id = select_libraries
browse(library_id)
