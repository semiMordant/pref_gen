#!/usr/bin/env ruby
require 'pry'

require './mongo.rb'
require './anilist.rb'
require './anime-planet.rb'
require './log.rb'

def tag_all_characters
  mongo['characters'].find({'tags': {'$exists': false}}).each { |character|
    i = 1
    begin
      log("Tagging '#{character['name']}' (#{character['_id']})")
      character['tags'] = character_tags(character)
      mongo['characters'].update_one({'_id': character['_id']}, character)
    rescue StandardError => error
      error("(#{character['_id']}) #{error}")
    end
  }

end

def full_db_populate
  puts "anilist auth code needed for db populate" if(ARGV.length < 1)
  auth = anilist_auth(ARGV[0])
  token = "#{auth['token_type']} #{auth['access_token']}"

  all_shows(token)
  all_manga(token)
  all_characters(token)
end

Pry.start
# tag_all_characters
