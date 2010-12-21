require 'rubygems'
require 'oauth'
require 'oauth-patch.rb'

CONSUMER_KEY = '5WqTIbVIwWeo40oUsiIwPw'
CONSUMER_SECRET = 'IoTny71a710EsYOU24OuoiWHwOivGC0c8mqtxcQKM'

consumer = OAuth::Consumer.new(
  CONSUMER_KEY,
  CONSUMER_SECRET,
  :site => 'http://twitter.com'
  #:proxy => 'http://proxy.fun.ac.jp:8080'
)

request_token = consumer.get_request_token

puts "Access this URL and approve => #{request_token.authorize_url}"

print "Input OAuth Verifier: "
oauth_verifier = gets.chomp.strip

access_token = request_token.get_access_token(
  :oauth_verifier => oauth_verifier
)

puts "Access token: #{access_token.token}"
puts "Access token secret: #{access_token.secret}"
