#!/usr/bin/env ruby

require "json"
require "gum"
require "lipgloss"
require "ostruct"
require "net/http"
require "json"

VERSION = "0.1.1"
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
  resp = Net::HTTP.get_response(uri)

  if resp.is_a?(Net::HTTPSuccess)
    return true
  else
    return false
  end
end

def jellyfin_get(path)
  uri = URI("#{SESSION.url}#{path}")
  req = Net::HTTP::Get.new(uri)
  req["X-Emby-Authorization"] = HEADERS

  resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end

  return resp
end

def get_libraries
  resp = jellyfin_get("/Users/#{SESSION.uid}/Views")
  data = JSON.parse(resp.body)
  libraries = data["Items"]

  libraries
end
def select_libraries
  libraries = get_libraries
  names = libraries.map { |lib| lib["Name"] }
  names.unshift("<<  Back")
  choice = Gum.choose(names, height: 25)
  return nil if choice == "<<  Back"
  selected = libraries.find { |lib| lib["Name"] == choice }
  selected["Id"]

end

def get_items(library_id)
  resp = jellyfin_get("/Users/#{SESSION.uid}/Items?ParentId=#{library_id}")
  data = JSON.parse(resp.body)
  items = data["Items"]

  items
end

def get_favorites
  resp = jellyfin_get("/Users/#{SESSION.uid}/Items?Filters=IsFavorite&Recursive=true")
  data = JSON.parse(resp.body)
  data["Items"]
end

def favorites
  items = get_favorites

  if items.empty?
    puts "No favorites found."
    return
  end

  names = items.map { |item| item["Name"] }
  names.unshift("<<  Back")
  choice = Gum.choose(names, height: 25)

  return if choice == "<<  Back"

  selected = items.find { |item| item["Name"] == choice }

  if selected["Type"] == "Episode" || selected["Type"] == "Movie"
    system("mpv", "#{SESSION.url}/Videos/#{selected['Id']}/stream?static=true&api_key=#{SESSION.token}")
  else
    browse(selected["Id"])
  end
end

def search_items(qry)
  enc = URI.encode_www_form_component(qry)
  resp = jellyfin_get("/Users/#{SESSION.uid}/Items?searchTerm=#{enc}&Recursive=true&Limit=25")
  data = JSON.parse(resp.body)
  data["Items"]
end

def search
  qry= Gum.input(placeholder: "Search...", header: "Search for a title")
  return if qry.nil? || qry.strip.empty?

  results = search_items(qry)

  if results.empty?
    puts "No results found."
    return
  end

  names = results.map { |item| item["Name"] }
  choice = Gum.choose(names, height: 25)
  selected = results.find { |item| item["Name"] == choice }

  if selected["Type"] == "Episode" || selected["Type"] == "Movie"
    system("mpv", "#{SESSION.url}/Videos/#{selected['Id']}/stream?static=true&api_key=#{SESSION.token}")
  else
    browse(selected["Id"])
  end
end

def browse(library_id)
  history = []
  current_id = library_id

  loop do
    items = get_items(current_id)

    if items.first && items.first["Type"] == "Episode"
      names = items.map { |ep| "#{ep['IndexNumber']}. #{ep['Name']}" }
      names.unshift("<<  Back")
      choice = Gum.choose(names, height: 25)

      if choice == "<<  Back"
        if history.empty?
          break
        else
          current_id = history.pop
          next
        end
      end

      selected = items.find { |ep| "#{ep['IndexNumber']}. #{ep['Name']}" == choice }
      system("mpv", "#{SESSION.url}/Videos/#{selected['Id']}/stream?static=true&api_key=#{SESSION.token}")
      next
    end

    names = items.map { |item| item["Name"] }
    names.unshift("<<  Back")
    choice = Gum.choose(names, height: 25)

    if choice == "<<  Back"
      if history.empty?
        break
      else
        current_id = history.pop
        next
      end
    end

    selected = items.find { |item| item["Name"] == choice }
    history.push(current_id)
    current_id = selected["Id"]
  end
end

def get_user_info(config)
  url = config["url"]
  uri = URI("#{url}/Users/AuthenticateByName")

  req = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/json"
  req["X-Emby-Authorization"] = 'MediaBrowser Client="Rubyfin", Device="PC", DeviceId="rubyfin", Version="0.1.0"'
  req.body = JSON.generate({
    "Username" => config["username"],
    "Pw" => config["password"]
  })

  resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end

  data = JSON.parse(resp.body)
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
  .border(:rounded)
  .border_foreground("#874BFD")
  .padding(1, 2)
  .width(60)
  .height(5)

user_info = get_user_info(config)

# puts user_info["token"]
# puts user_info["uid"]

HEADERS = 'MediaBrowser Client="Rubyfin", Device="PC", DeviceId="rubyfin", Version="' + VERSION + '", Token="' + user_info["token"] + '"'

# session: url, username, password, token, uid
SESSION = OpenStruct.new(config.merge(user_info))

loop do
  action = Gum.choose(["Browse Library", "Search", "Favorites", "Quit"], height: 25)

  if action == "Search"
    search
  elsif action == "Favorites"
    favorites
  elsif action == "Quit"
    break
  else
    library_id = select_libraries
    browse(library_id)
  end
end
