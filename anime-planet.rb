require 'nokogiri'
require 'faraday'
require 'cgi'

require './log.rb'

def character_tags(document)
  parsed_html = search_or_page(document)
  unless parsed_html
    warn("Missing anime-planet page '#{document['name']}' (#{document['_id']})")
    return []
  end

  tags_from_page(parsed_html)
end

def search_all_responses(parsed_html, media, name)
  base_url = 'https://www.anime-planet.com'
  total_pages = search_num_pages(parsed_html)

  found_path = search_one_page(parsed_html, media)
  return found_path if found_path

  2.upto(total_pages){ |x|
    res = Faraday.get("#{base_url}/characters/all?name=#{CGI.escape(name)}&page=#{x}")
    return nil unless res
    parsed_html = Nokogiri.parse(res.body)

    found_path = search_one_page(parsed_html, media)
    return found_path if found_path
  }
  nil
end

def search_one_page(parsed_html, media)
  rows = parsed_html.xpath('//tbody/tr')
  row = rows.detect { |row|
    media.any? { |x|
      row.xpath("td[contains(@class,'tableAnime')]/div/ul/li").map(&:text).include? x
    }
  }
  row.xpath("td[contains(@class,'tableAvatar')]/a").first.attr('href') if row
end

def search_num_pages(parsed_html)
  pages = parsed_html.xpath("//div[contains(@class,'pagination')]/ul/li")[-2]
  pages ? pages.text.to_i : 0
end

def tags_from_page(parsed_html)
  parsed_html.xpath("//div[contains(@class,'tags')]/ul/li").map{ |x| x.text}
end

def search_or_page(document)
  base_url = 'https://www.anime-planet.com'
  res = Faraday.get("#{base_url}/characters/all?name=#{CGI.escape(document['name'])}")
  if res.status == 302
    path = res.headers['location']
  else
    parsed_html = Nokogiri.parse(res.body)
    num_pages = search_num_pages(parsed_html)
    if num_pages > 50
      warn("Too many search pages for '#{document['name']}' (#{document['_id']})")
      return nil
    end
    media = document['media'].map{|x| x['title']}
    path = search_all_responses(parsed_html, media, document['name'])
  end

  character_by_path(path) if path
end

def character_by_path(path)
  base_url = 'https://www.anime-planet.com'
  res = Faraday.get("#{base_url}#{path}")
  Nokogiri.parse(res.body)
end
