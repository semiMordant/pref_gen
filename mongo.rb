require 'mongo'
require 'faraday'

def mongo
  @client ||= Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'animeme')
end

def upsert(collection, data, adapter)
  mongo[collection].update_one({aniId: data["id"]}, adapter[data], {upsert: true})
end

def characters_by_name(name)
  mongo[:characters].find(name: name).to_a
end

def document_by_id(collection, id)
  mongo[collection].find("_id": BSON::ObjectId(id)).first
end
