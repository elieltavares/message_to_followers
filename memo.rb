require 'radiator'
require 'yaml'
require 'time_difference'

@patch_file = 'config.yml'
## Debug
unless File.exist?(@patch_file)
	puts ("File #{@patch_file} don't exist")
end

@config = YAML.load_file(@patch_file)
@options = @config[:chain_options]
keys = @config[:account]
amount = @config[:amount]
memo = @config[:memo]
api = Radiator::DatabaseApi.new(@options.dup)
@account_done = []

keys.each do |key|
	account, active_wif = key.split(' ')
	followApi = Radiator::FollowApi.new(@options.dup)
	n_follow = followApi.get_follow_count(account).result.follower_count
	followers = []
	until n_follow == followers.count
		followers += followApi.get_followers(account, followers.last, 'blog', 1000).result.map(&:follower)
		followers = followers.uniq
	end
	number = 0
	followers.each do |followname|
		response = api.get_state("@#{followname}")
		date = response.result.accounts["#{followname}"].last_post
		Time.zone = "UTC"
		date = Time.zone.parse(date)
		datenow = Time.now.getlocal('-00:00')
		diference = TimeDifference.between(date, datenow).in_hours
		if diference > 36
			puts "#{followname}is a dead follow"
		else
			tx = Radiator::Transaction.new(wif: active_wif)
			transfer = {
			  type: :transfer,
			  from: account,
			  to: followname,
			  amount: amount,
			  memo: memo
			}
		
			tx.operations << transfer
			puts tx.process(true)
			number+=1
			puts "You seed a messager to #{followname} - Text: #{memo}"
		end
	end
	spent = number * (amount.to_f)
	puts "You have #{number} alive follow, you spent: #{spent}SBD"
end
