#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'musix_match'

def words_limit(word, limit)
    string_arr = word.split(' ')
    string_arr.count > limit ? "#{string_arr[0..(limit-1)].join(' ')}..." : word
end

secrets = YAML::load(File.open('secrets.yaml'))

MusixMatch::API::Base.api_key = secrets['musixmatch_api_key']

uri = URI.parse(secrets['playlist_url'])
http = Net::HTTP.new(uri.host, uri.port)

http.use_ssl = true
http.cert = OpenSSL::X509::Certificate.new(File.read(secrets['cert_file']))
http.key = OpenSSL::PKey::RSA.new(File.read(secrets['cert_file']))

p "requesting 6music album of the day"
response = http.request(Net::HTTP::Get.new(uri.request_uri))

p "parsing json"
json = JSON.parse(response.body)	

playlist_name = json['playlistItems'].first['playlistName']

p "got #{playlist_name}"

json['playlistItems'].shuffle.each do |playlistItem|
	track_title = playlistItem['item']['title']

	unless playlistItem['item']['artist'].nil?
		artist_name = playlistItem['item']['artist']['name']
		p "searching for #{track_title} by #{artist_name}"

		track_search = MusixMatch.search_track(:q_artist => artist_name, :q_track => track_title)

		track_search.each do |track|
			p "searching for lyrics for #{track.track_name} by #{track.artist_name}"

			l = MusixMatch.get_lyrics(track.lyrics_id)

			if l.status_code == 200 && lyrics = l.lyrics
				ly = lyrics.lyrics_body.gsub("******* This Lyrics is NOT for Commercial use *******", "")

				p "singing #{track.track_name} by #{track.artist_name}"

				unless ly.nil? || ly.empty?
					index = ly.index("\n\n")
					to_sing = words_limit(ly[0, index].gsub("\n", ". \n"), 25)

					`/usr/bin/open -a "/Applications/Google Chrome.app" "https://www.crumbles.co/?q=#{URI.escape(to_sing)}"`

					abort("opened chrome")
				end
			end
		end

	end
end