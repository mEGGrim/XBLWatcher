require 'rubygems'
require 'rubytter'
require 'oauth'
require 'kconv'

$KCODE = "UTF-8"

class XboxLiveRubytter
	def initialize(access_token, access_token_secret, proxy=nil)
		@CONSUMER_KEY = '5WqTIbVIwWeo40oUsiIwPw'
		@CONSUMER_SERCRET = 'IoTny71a710EsYOU24OuoiWHwOivGC0c8mqtxcQKM'
		@ACCESS_TOKEN = access_token
		@ACCESS_TOKEN_SERCTET = access_token_secret

		options = {:site => 'http://api.twitter.com'}
		if proxy then
			options['proxy'] = proxy
		end
		@consumer = OAuth::Consumer.new(
			@CONSUMER_KEY,
			@CONSUMER_SERCRET,
			options
		)
		
		@access_token = OAuth::AccessToken.new(
			@consumer,
			@ACCESS_TOKEN,
			@ACCESS_TOKEN_SERCTET
		)
		@rubytter = OAuthRubytter.new(@access_token)
	end
	
	def postTwitter(tweet)
		begin	
			@rubytter.update(tweet)
		rescue Rubytter::APIError
			puts 'Twitter API Error.'
			if $!.to_s == "Status is a duplicate." then
				puts 'ポストが重複しています'
			else
				puts $!.to_s
			end
		rescue Timeout::Error
			puts 'Timeout Error. Retry'
			retry
		rescue
			puts '予期せぬエラーが発生'
			p $!
			puts $@
			puts "'" + tweet + "' is failed."
		end
	end
end

