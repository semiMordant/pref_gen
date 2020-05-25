require 'faraday'

def refresh(refresh_token)
end

def hash_to_date(hash)
  "#{hash["month"]}/#{hash["day"]}/#{hash["year"]}"
end

status = {
  finished: "FINISHED",
  releasing: "RELEASING",
  future: "NOT_YET_RELEASED",
  cancelled: "CANCELLED"
}

default_anime_adapter = ->(show) {
  status = {
    finished: "FINISHED",
    releasing: "RELEASING",
    future: "NOT_YET_RELEASED",
    cancelled: "CANCELLED"
  }
  anime = {
    aniId: show["id"],
    title: {
      english: show["title"]["english"],
      romaji: show["title"]["romaji"]
    },
    image: show["coverImage"]["large"],
    aired: "#{show["season"]} #{show["seasonYear"]}",
    format: show["format"],
    status: show["status"]
  }
  anime[:startDate] = hash_to_date(show["startDate"]) unless show["status"] == status[:future]
  if show["status"] == status[:finished] || show["status"] == status[:cancelled]
    output[:endDate] = hash_to_date(show["endDate"])
    output[:episodes] = show["episodes"]
  end
  anime
}

default_manga_adapter = ->(manga) {
  status = {
    finished: "FINISHED",
    releasing: "RELEASING",
    future: "NOT_YET_RELEASED",
    cancelled: "CANCELLED"
  }

   output = {
    aniId: manga["id"],
    title: {
      english: manga["title"]["english"],
      romaji: manga["title"]["romaji"]
    },
    chapters: manga["chapters"],
    volumes: manga["volumes"],
    image: manga["coverImage"]["large"],
    aired: "#{manga["season"]} #{manga["seasonYear"]}",
    format: manga["format"],
    status: manga["status"]
  }
  output[:startDate] = hash_to_date(manga["startDate"]) unless manga["status"] == status[:future]
  if manga["status"] == status[:finished] || manga["status"] == status[:cancelled]
    output[:endDate] = hash_to_date(manga["endDate"])
    output[:volumes] = manga["volumes"]
    output[:chapters] = manga["chapters"]
  end
  output
}

default_character_adapter = ->(character) {
  output = {
    aniId: character["id"],
    name: character["name"]["full"],
    image: character["image"]["large"],
    media: character['media']['edges'].map { |appearance|
      node = appearance['node']
      type = node['type'].downcase
      media = mongo[type].find({aniId: node['id']}).first
      media && {'id': media['_id'].to_s, 'title': media['title'].values.compact.first, 'type': type}
    }.compact
  }
}

def all_shows(token, adapter = default_anime_adapter)
  page_num = 1;
  next_page = true;
  while next_page
    res = show_page(page_num, token)
    next_page = res["data"]["Page"]["pageInfo"]["hasNextPage"]
    page_num += 1
    res["data"]["Page"]["media"].each { |show|
      upsert(:anime, show, adapter)
    }
    sleep(2/3.0)
  end
end

def all_manga(token, adapter = default_manga_adapter)
  page_num = 1;
  next_page = true;
  while next_page
    res = manga_page(page_num, token)
    next_page = res["data"]["Page"]["pageInfo"]["hasNextPage"]
    page_num += 1
    res["data"]["Page"]["media"].each { |manga|
      upsert(:manga, manga, adapter)
    }
    sleep(2/3.0)
  end
end

def all_characters(token, adapter = default_character_adapter)
  page_num = 1;
  next_page = true;
  while next_page
    res = character_page(page_num, token)
    next_page = res["data"]["Page"]["pageInfo"]["hasNextPage"]
    page_num += 1
    res["data"]["Page"]["characters"].each { |char|
      upsert(:characters, char, adapter)
    }
    sleep(2/3.0)
  end
end

def manga_page(page, token)
  query = <<-GRAPHQL
    query {
      Page (page: #{page}, perPage: 50) {
        media(type:MANGA) {
          title {
            romaji
            english
          }
          coverImage {
            large
          }
         	chapters
          volumes
          format
          id
          status
          startDate {
            year
            month
            day
          }
          endDate {
            year
            month
            day
          }
        }
        pageInfo {
          hasNextPage
          total
        }
      }
    }
  GRAPHQL

  internal_request(query, token)
end

def show_page(page, token)
  query = <<-GRAPHQL
    query {
      Page (page: #{page}, perPage: 50) {
        media(type:ANIME) {
          title {
            romaji
            english
          }
          coverImage {
            large
          }
          season
          seasonYear
          episodes
          format
          id
          status
          startDate {
            year
            month
            day
          }
          endDate {
            year
            month
            day
          }
        }
        pageInfo {
          hasNextPage
        }
      }
    }
  GRAPHQL

  internal_request(query, token)
end

def character_page(page, token)
  query = <<-GRAPHQL
    query {
      Page (page: #{page}, perPage: 50) {
       characters {
        id
        name {
          full
        }
        image {
          large
        }
        media {
          edges {
            node {
              id
              type
            }
          }
        }
      }
        pageInfo {
          hasNextPage
          total
        }
      }
    }
  GRAPHQL

  internal_request(query, token)
end

def internal_request(query_string, token)
  url = "https://graphql.anilist.co"
  headers = [
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Authorization" => token
  ]
  body = { query: query_string }

  response = Faraday.post(url, body, headers)
  JSON.parse(response.body) if response.status == 200
end

def anilist_auth(code)
  client_id = "2283"
  client_secret = "XUu7gXWPH3CCXKhVmXV75o7DPAEPE5MUqAdONCkN"
  redirect_uri = "https://www.example.com"

  body = {
    "grant_type" => "authorization_code",
    "client_id" => client_id,
    "client_secret" => client_secret,
    "redirect_uri" => redirect_uri,
    "code" => code
  }

  headers = [
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  ]

  url = "https://anilist.co/api/v2/oauth/token"

  res = Faraday.post(url, body, headers)
  JSON.parse(res.body) if res.status == 200
end
