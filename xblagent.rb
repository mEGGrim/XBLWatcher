require 'rubygems'
require 'Mechanize'
require 'logger'

$KCODE = "UTF-8"

class XboxLiveAgent
	attr_accessor :accountid, :password, :agent

	def initialize(liveaccount_id, liveaccount_pass, proxy_host=nil, proxy_port=nil)
		@accountid = liveaccount_id
		@password = liveaccount_pass

		@agent = Mechanize.new
		if proxy_host and proxy_port then
			@agent.set_proxy(proxy_host, proxy_port)
		end
		@agent.user_agent_alias = 'Windows IE 7'
		@agent.follow_meta_refresh = false
		#@agent.log = Logger.new($stdout)
		#@agent.log.level = 1 # ignore DEBUG
	end

	def getTargetPage(targetUrl)
		page = self.agent.get(targetUrl)
		#遷移過程でログインページなどにリダイレクトされるのでそこら辺の処理
		urlPattern = Regexp.new(page.uri.to_s)
		# 遷移過程で無限ループするようなら抜ける為のカウンタ。例外発生させる
		# TODO: もうちょいスマートなやり方ないか考える
		loopcounter = 0
		begin
			#ページ遷移の過程でCookieの送信を求められるページにたどり着いた場合にform送信を行う
			if /login.srf/ =~ page.uri.to_s then
				#ログインページに飛ばされた場合の処理
				form = page.forms.first
				form.field_with("name" => 'login').value = self.accountid 
				form.field_with("name" => 'passwd').value = self.password
				page = form.submit
			elsif /ppsecure/ =~ page.uri.to_s
				#ページ遷移の過程でCookieの送信を求められるページにたどり着いた場合にform送信を行う
				form = page.forms.first
				form['login'] = self.accountid
				form["passwd"] = self.password
				page = form.submit
			end 
			urlPattern = Regexp.new(page.uri.to_s)
			# HTMLの取得が終わらないリダイレクト地獄に陥ってる場合は例外	
			loopcounter +=1
			if loopcounter > 10 then raise GetHTMLError end
		end while !urlPattern.match(targetUrl) and page.uri.to_s != targetUrl
		return page
	end

	def getRecentStatusAndPoint()
		#http://live.xbox.com/ja-JP/MyXbox/Profileの自分のページから最新のステータス及び実績総ポイントを取得
		#戻り値はステータスと実績ポイントの配列
		page = self.getTargetPage('http://live.xbox.com/ja-JP/MyXbox/Profile')
		if !page then return nil end
		status = page.search("div#CurrentActivity").inner_text
		if status.strip! == "" then status = "オフライン" end
		status = {'body' => status, 'gameTitle' => '', 'gameStatus' => ''}
		point = page/'/html/body/div/div[2]/div/div/div/div/div'
		point = point[0].inner_text.to_i
		return [status, point]
	end
	
	def getAllGameAchievementsScore()
		hash = Hash.new
		page = self.getTargetPage('http://live.xbox.com/ja-JP/GameCenter')
		if !page then return nil end
		games = page.search("div[@class='LineItem']")
		games.each do |game|
			title = game.at("a[@class='nohover']").inner_text
			score = game.at("div[@class='GamerScore\ Stat']").inner_text.match(/([0-9]*) \/.*/)[0].to_i
			titleID = game.at("div[@class='grid-7\ lastgridchild']").at("a[@class='nohover']")['href'].match(/([0-9]*)$/)[0]
			hash[title] = [titleID, score]
		end
		return hash
	end

	# あるゲームの最新実績を取得する
	# 引数はタイトル固有のIDと、取得したい実績ポイントの合計
	def getNewAchievements(gameTitle, titleID, scoreDiff)
		page = self.getTargetPage('http://live.xbox.com/ja-JP/GameCenter/Achievements?titleId=' + titleID)
		if !page then return nil end
		newAchievementsArray = Array.new
		# ゲームのタイトル
		newAchievementsArray << gameTitle
		# 実績の総スコア
		scores = page.at("div[@class='RightColumnItem\ GameProgressBlock']").at("div[@class='GamerScore\ Stat']").inner_text.match(/([0-9]*) \/ ([0-9]*)/)
		newAchievementsArray << scores.to_a[2]
		achievementTotalScore = scores.to_a[1].to_i
		achievementsList = page.search("div[@class='SpaceItem']")
		achievementsList.each do |achievement|
			newAchievementHash = Hash.new
			achievementTitle = achievement.at('h3').inner_text
			achievementScore = achievement.at("div[@class='Stat\ GamerScore']").inner_text
			newAchievementHash['achievementTitle'] = achievementTitle
			newAchievementHash['achievementScore'] = achievementScore
			newAchievementHash['gameTotalScore'] = achievementTotalScore.to_s
			achievementTotalScore -= achievementScore.to_i
			newAchievementsArray << newAchievementHash
			scoreDiff -= newAchievementHash['achievementScore'].to_i
			if scoreDiff <= 0 then break end
		end
		return newAchievementsArray
	end
end

class GetHTMLError < Exception; end
