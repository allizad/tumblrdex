require 'net/https'
require 'json'

BLOG_NAME = "maydesignsblog"
FIND_JSON_SUBSTRING = %r{\A[^{]+({.*})[^}]+\Z}
ELASTICSEARCH_URL = "https://l3l2c4xnsz:jqay9as9r4@allisons-first-start-8002833502.us-west-2.bonsai.io"


page = 0
per_page = 10


def get_response(page, per_page)
  uri = URI("http://#{BLOG_NAME}.tumblr.com/api/read/json")
  start = page * per_page
  params = { num: per_page, start: start }
  uri.query = URI.encode_www_form(params)
  http = Net::HTTP.new(uri.host, uri.port)
  req = Net::HTTP::Get.new(uri)
  res = http.request(req)
  # strip JSONP
  res.body =~ FIND_JSON_SUBSTRING
  json = JSON.parse($1)
end

def send_to_elasticsearch(posts)
  puts "send_to_elasticsearch"
  updates = posts.map do |post|
    meta = { index: { _index: BLOG_NAME, _type: post['type'], _id: post['id'] }}
    "#{meta.to_json}\n#{post.to_json}\n"
  end
  bulk_update = updates.join
  uri = URI("#{ELASTICSEARCH_URL}/_bulk")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Post.new(uri)
  # authorization
  req.basic_auth uri.user, uri.password
  req.body = bulk_update
  res = http.request(req)
  puts res.body
end

json = get_response(0, 0)
total = json['posts-total']

loop do
  break if page * per_page >= total
  json = get_response(page, per_page)

  # do stuff with json
  puts json['posts'].map{ |p| p['url-with-slug']}.join("\n")
  send_to_elasticsearch(json['posts'])
  page += 1
end
