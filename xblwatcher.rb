require "xblagent.rb"

$KCODE = "UTF-8"

class XboxLiveWatcher
	attr_accessor :status, :achievementsHash, :outputFunction, :lastPrintStatusTime, :lastActivateTime
	def initialize(agent, config)
		if File.exist?('watcherData.yaml') then
			puts 'Initialize XBLWatcher From File.'
			self.initializeFromFile(agent)
			puts 'Complete Initialize XBLWatcher From File.'
		else
			puts 'Initialize XBLWatcher From WEB.'
			self.initializeFromWEB(agent)
			self.saveWatcher()
			puts 'Complete Initialize XBLWatcher From File.'
		end
	end

	def initializeFromFile(agent)
		obj = YAML.load_file('watcherData.yaml')
		@status = obj.status
		@achievementsHash = obj.achievementsHash
		@lastPrintStatusTime = obj.lastPrintStatusTime
		@lastActivateTime = obj.lastActivateTime
	end

	def initializeFromWEB(agent)
		# ステータス及び総実績ポイント
		newStatus = agent.getRecentStatusAndPoint()
		@status = {'body' => 'オフライン', 'gameTitle' => 'オフライン', 'gameStatus' => '', 'totalScore' => 0}
		@status['body'] = newStatus['body']
		@status['totalScore'] = newStatus['totalScore']
		# 実績取得リスト
		@achievementsHash = Hash.new
		# WEBからachievementsHash取得して初期化
		puts "Loading achievements data from web."
		@achievementsHash = agent.getAllGameAchievementsScore()
		puts "Complete loading achievements data from web."
		
		# ステータス変化ポストに制限をかけるためのタイマー
		# 初期化時はかなり前の時刻にすることで初期起動時にステータス出力が実行されるようにする
		@lastPrintStatusTime = Time.now - (60 * 60)

		# 最終起動時刻を記録するタイマー
		# 時間が経ちすぎていると怒濤の実績解除ポストする可能性があるので危険
		@lastActivateTime = Time.now
	end

	def outputFunction(xblrubytter, message)
		puts message
		xblrubytter.postTwitter(message)
	end
	
	# XBLWatcher(スコア、ゲームの状態)をファイルに保存
	def saveWatcher()
		file = File.open('watcherData.yaml', 'w')
		file.puts self.to_yaml()
		file.close
	end
	

	# ステータス/実績スコアに変化があるかを巡回
	def watchXBL(agent, xblrubytter, messageHash)
		@lastActivateTime = Time.now

		# 最新のステータスと総実績ポイントを取得
		newStatus = agent.getRecentStatusAndPoint()
		
		# ステータスに変化があるかどうかの判定／変化がある場合にポスト
		diffStatus(newStatus, agent, xblrubytter, messageHash)

		# 実績スコアに変化あり
		if @status['totalScore'].to_i < newStatus['totalScore'] then
			@status['totalScore'] = newStatus['totalScore']
			self.diffAchievements(agent, xblrubytter, messageHash)
		end
	end
	
	# ステータス/実績スコアを最新の状態にする
	def reloadXBL(agent)
		# XBLWatcherを最新の状態にする
		# 前回起動時から時間が経ちすぎてる時用
		@lastActivateTime = Time.now

		# 最新のステータスと総実績ポイントを取得
		newStatus = agent.getRecentStatusAndPoint()
		
		# ステータスの初期化
		# Xbox.comの場合、及び【n(分|時間)前に】はオフライン扱いにする
		if newStatus['body'] =~ /Xbox\.com$/ or newStatus['body'] =~ /.*(分|時間)前に.*/ or newStatus['body'] == '' or  newStatus['body'] == "オフライン" or newStatus['body'] == 'Xbox Dashboard' then
			newStatus['gameTitle'] = "オフライン"
		else
			matching = newStatus['body'].gsub(/\n|\r/, ' ').gsub(/  /, ' ').match(/([^\-]*)-(.*)/)
			#if !matching.to_a[1] then p 'matching',matching end
			#if !matching.to_a[1] then p 'newStatus',newStatus end
			newStatus['gameTitle'] = matching.to_a[1].strip
			newStatus['gameStatus'] = matching.to_a[2].strip
		end

		# 実績スコアに変化あり
		if @status['totalScore'].to_i < newStatus['totalScore'] then
			@status['totalScore'] = newStatus['totalScore']
			recentAchievements = agent.getAllGameAchievementsScore()
			recentAchievements.each_key do |game|
				# 新しいゲームを発見
				if !@achievementsHash.has_key?(game) then
					achievements = agent.getNewAchievements(game, @achievements[game][0], recentAchievements[game][1])
					gameTitle = achievements[0]
					gamePerfectScore = achievements[1]
					
				# スコアに変動があった
				elsif recentAchievements[game][1] > @achievementsHash[game][1]
					achievements = agent.getNewAchievements(game, @achievementsHash[game][0], recentAchievements[game][1] - @achievementsHash[game][1])
					gameTitle = achievements[0]
					gamePerfectScore = achievements[1]
				end
			end
			@achievementsHash = recentAchievements
		end

		@status = newStatus
	end

	# ステータスが変わったときに出力を行う
	def diffStatus(newStatus, agent, xblrubytter, messageHash)
		# Xbox.comの場合、及び【n(分|時間)前に】はオフライン扱いにする
		if newStatus['body'] =~ /Xbox\.com$/ or newStatus['body'] =~ /.*(分|時間)前に.*/ or newStatus['body'] == '' or  newStatus['body'] == "オフライン" or newStatus['body'] == 'Xbox Dashboard' then
			newStatus['gameTitle'] = "オフライン"
		else
			matching = newStatus['body'].gsub(/\n|\r/, ' ').gsub(/  /, ' ').match(/([^\-]*)-(.*)/)
			#if !matching.to_a[1] then p 'matching',matching end
			#if !matching.to_a[1] then p 'newStatus',newStatus end
			newStatus['gameTitle'] = matching.to_a[1].strip
			newStatus['gameStatus'] = matching.to_a[2].strip
		end

		# 新しいゲームがオフライン以外で以前のステータスがオフライン
		# ゲームが起動したと思われる
		if newStatus['gameTitle'] != 'オフライン' and @status['gameTitle'] == 'オフライン' then
			puts "/////initialize//////////"
			@status = newStatus
			outputFunction(xblrubytter, self.translateMessage(messageHash['activateMessage']))
			outputFunction(xblrubytter, self.translateMessage(messageHash['titleMessage']))
			# 新しいゲームがオフラインで以前のゲームがオフライン以外
			# ゲームが終了したと思われる
		elsif newStatus['gameTitle'] == 'オフライン' and @status['gameTitle'] != 'オフライン' then
			puts "/////deactivate//////////"
			@status['gameTitle'] = "オフライン"
			outputFunction(xblrubytter, self.translateMessage(messageHash['deactivateMessage']))
			# ゲームのタイトルに変化あり
			# 新しいゲームの起動
		elsif newStatus['gameTitle'] != @status['gameTitle'] then
			puts "/////newTitle//////////"
			@status = newStatus
			outputFunction(xblrubytter, self.translateMessage(messageHash['titleMessage']))
			# ゲームのタイトルに変化なし かつ オフラインではない かつ ゲームのステータスに変化あり
			# 新しいゲームステータス
		elsif newStatus['gameTitle'] != 'オフライン' and newStatus['gameTitle'] == @status['gameTitle'] and newStatus['gameStatus'] != @status['gameStatus']
			# 最後にステータスを出力した時点から十五分経っていれば出力する
			if @lastPrintStatusTime + (60 * 5) < Time.now
				# 前回の十五分
				@lastPrintStatusTime = Time.now
				puts "/////newStatus//////////"
				@status = newStatus
				outputFunction(xblrubytter, self.translateMessage(messageHash['statusMessage']))
			# 最後にステータスを出力した時点から十五分経っていなければ出力しない
			else
				puts "/////まだ十五分経ってません//////////" + '  last printed: ' + @lastPrintStatusTime.to_s
			end
		end
	end

	# 新しい実績を探索して出力
	def diffAchievements(agent, xblrubytter, messageHash)
		recentAchievements = agent.getAllGameAchievementsScore()
		recentAchievements.each_key do |game|
			# 新しいゲームを発見
			if !@achievementsHash.has_key?(game) then
				achievements = agent.getNewAchievements(game, @achievements[game][0], recentAchievements[game][1])
				gameTitle = achievements[0]
				gamePerfectScore = achievements[1]
				achievements.each do |achievement|
					outputFunction(xblrubytter, self.translateAchievementMessage(messageHash['achievementMessage'], gameTitle, gamePerfectScore, achievement))
				end
				# スコアに変動があった
			elsif recentAchievements[game][1] > @achievementsHash[game][1]
				achievements = agent.getNewAchievements(game, @achievementsHash[game][0], recentAchievements[game][1] - @achievementsHash[game][1])
				gameTitle = achievements[0]
				gamePerfectScore = achievements[1]
				achievements[2..-1].reverse.each do |achievement|
					outputFunction(xblrubytter, self.translateAchievementMessage(messageHash['achievementMessage'], gameTitle, gamePerfectScore, achievement))
				end
			end
		end
		@achievementsHash = recentAchievements
	end

	# messageを置換する
	def translateMessage(originalMessage)
		message = originalMessage.gsub(/\$title/, @status['gameTitle'])
		message.gsub!(/\$title/, @status['gameTitle'])
		message.gsub!(/\$status/, @status['gameStatus'])
		message.gsub!(/\$totalScore/, @status['totalScore'].to_s)
		message.gsub!(/\$gameTotalScore/, @status['gameTotalScore'].to_s)
		message.gsub!(/\$perfectScore/, @status['gamePerfectScore'].to_s)
		return message
	end

	#実績解除メッセージの置換
	def translateAchievementMessage(originalMessage, gameTitle, gamePerfectScore, achievementHash)
		message = originalMessage.gsub(/\$title/, gameTitle)
		message.gsub!(/\$achievement/, achievementHash['achievementTitle'])
		message.gsub!(/\$point/, achievementHash['achievementScore'])
		message.gsub!(/\$gameTotalScore/, achievementHash['gameTotalScore'])
		message.gsub!(/\$perfectScore/, gamePerfectScore)
		return message
	end
end
