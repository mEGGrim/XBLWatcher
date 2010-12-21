require 'rubygems'
require 'Mechanize'

$LOAD_PATH << File.dirname(__FILE__)
require "xblagent.rb"
require "xblwatcher.rb"
require "xblrubytter.rb"
require "xblconfig.rb"

$KCODE = "UTF-8"

# 設定ファイルの読み込み
config = XBLWatcherConfig.new

# プロキシ使用時
#proxy_host = 'proxy.fun.ac.jp'
#proxy_port = 8080
#$xblrubytter = XboxLiveRubytter.new(config.Twitter_ACCESS_TOKEN,
#config.Twitter_ACCESS_TOKEN_SECRET,
#'http://' + proxy_host + ':' + proxy_port.to_s)
#agent = XboxLiveAgent.new(config.XBL_MailAddress, config.XBL_Password, proxy_host, proxy_port) 
#watcher = XboxLiveWatcher.new(agent)

# Twitter通信クラスを初期化
$xblrubytter = XboxLiveRubytter.new(config.accountHash['Twitter_ACCESS_TOKEN'], config.accountHash['Twitter_ACCESS_TOKEN_SECRET'])

#XboxLiveAgentはXboxLiveとの通信を行います
agent = XboxLiveAgent.new(config.accountHash['XBL_MailAddress'], config.accountHash['XBL_Password']) 

#XboxLiveWatcherはXboxLiveAgentの通信結果を使って実績やステータスの監視を行います
watcher = XboxLiveWatcher.new(agent, config)



#実績取得のテスト。意図的にスコアに変動を与える
#watcher.status['totalScore']-= 25
#watcher.achievementsHash['コール オブ デューティ ブラックオプス'][1] -= 50
#watcher.achievementshash['bayonetta'][1] -= 40
#watcher.achievementshash['怒首領蜂 大復活 ver1.5'][1] -= 40
#watcher.achievementshash['ac for answer'][1] -= 40
#watcher.achievementshash['dead rising 2'][1] -= 40
#



begin
	watcher.watchXBL(agent, $xblrubytter, config.messageHash)
	watcher.saveWatcher()
	#watcher.reloadXBL(agent)
	#watcher.saveWatcher()
rescue
	puts 'Twitter関係以外の部分で予期せぬエラー'
	puts $!
	puts $@
rescue GetHTMLError
	puts 'HTMLの取得に失敗しました'
end
