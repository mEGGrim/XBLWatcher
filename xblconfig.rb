require 'yaml'
$KCODE = "UTF-8"

class XBLWatcherConfig
	attr_accessor :accountHash, :messageHash
	def initialize
		@accountHash = Hash.new
		@messageHash = Hash.new
		
		if !File.exist?(ENV['HOME'] + '/.xblwatcher') then 
			abort('Directory ' + ENV['HOME'] + '/.xblwatcher is not exist')
		end

		# カレントディレクトリを移動
		Dir.chdir(ENV['HOME'] + '/.xblwatcher')

		# account.yamlが存在していれば設定をロードする
		if File.exist?('account.yaml') then
			@accountHash = YAML.load_file('account.yaml')
		else
			puts '~/.xblwatcher/account.yaml does not exist.'
			self.saveHashToFile( dataHash = {
							'Twitter_ACCESS_TOKEN' => '',
							'Twitter_ACCESS_TOKEN_SECRET' => '',
							'XBL_MailAddress' => '',
							'XBL_Password' => ''
			}, 'account.yaml')
			abort('Create ~/.xblwatcher/account.yaml. Please write config.')
		end

		# message.yamlが存在していればTwitterに投稿するメッセージのテンプレートを読み込む
		# 存在しない場合は生成する
		if !File.exist?('message.conf') then
			abort('message.conf does not exist.')
		end
		file = File.open('message.conf')
		file.each do |line|
			@messageHash[line.match(/^([^=]*)=(.*)$/).to_a[1]] = line.match(/^([^=]*)=(.*)$/).to_a[2]
		end
		file.close
	end

	def saveHashToFile(hash, filename)
		file = File.open(filename, 'w')
		file.puts hash.to_yaml
		file.close
	end
end
