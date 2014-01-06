require 'sinatra'
require 'json'
require 'net/http'
require 'uri'

configure do
	set :city_list, {
		"SEA" => "Seattle"
	}
end

get '/' do
	@show_results = false
	erb :index
end

post '/search' do
	@show_results = true
	@departure_date = params["departure"]
	@arrival_date = params["arrival"]

	departure = @departure_date.match(/([\d]{2})\/([\d]{2})\/([\d]{4}) ([\d]{1,2}):([\d]{2}) (AM|PM)/)
	arrival = @arrival_date.match(/([\d]{2})\/([\d]{2})\/([\d]{4}) ([\d]{1,2}):([\d]{2}) (AM|PM)/)

	@results, @valid = getResults(params["city"], departure, arrival)
	
	erb :index
end

def getResults(city, departure, arrival)

	unless settings.city_list.has_key? city
		return [nil, false]
	end

	d_date = "#{departure[3]}-#{departure[1]}-#{departure[2]}"
	d_hour = departure[6] == "PM" ? (departure[4].to_i + 12) * 60 : departure[4].to_i * 60
	a_date = "#{arrival[3]}-#{arrival[1]}-#{arrival[2]}"
	a_hour = arrival[6] == "PM" ? (arrival[4].to_i + 12) * 60 : arrival[4].to_i * 60

	uri = URI.parse('https://www.google.com/flights/rpc')
	http = Net::HTTP.new(uri.host, uri.port)
	http.use_ssl = true
	http.verify_mode = OpenSSL::SSL::VERIFY_NONE
	request = Net::HTTP::Post.new(uri.request_uri)
	request.body = '[,[[,"ad","[,[,[[,[\"'+city+'\"],,\"'+d_date+'\",,[,'+"#{d_hour}"+',1440],,,0],[,,[\"'+city+'\"],\"'+a_date+'\",,,[,'+"#{a_hour}"+',1260],,0]]],[,25.725122085289655,-128.82421875,48.51982981873451,-66.17578125],4]","1087832005431478",3]],[,[[,"b_al","pd:69"],[,"b_ahr","pd:s"],[,"b_al","sr:72"],[,"b_ahr","sr:s"],[,"b_al","fs:51"],[,"b_ahr","fs:s"],[,"b_lr","13:217"],[,"b_lr","19:0"],[,"b_lr","13:219"],[,"b_lr","3:351"],[,"b_qu","0"],[,"b_qc","1"]]]]'
	#request.body = '[,[[,"ad","[,[,[[,[\"SEA\"],,\"2014-01-24\",,[,1020,1440],,,0],[,,[\"SEA\"],\"2014-01-26\",,,[,900,1260],,0]]],[,-53.31746531011099,176.2265625,78.90148328853348,66.8203125],4]","1272831854995598",45]],[,[[,"b_al","pd:69"],[,"b_ahr","pd:s"],[,"b_lr","15:24"],[,"b_lr","8:24"],[,"b_ca","50:525833"],[,"b_lr","15:17"],[,"b_qu","0"],[,"b_qc","1"]]]]'
	#request.body = '[,[[,"ad","[,[,[[,[\"SEA\"],,\"2014-01-24\",,[,1020,1440],,,0],[,,[\"SEA\"],\"2014-01-26\",,,[,900,1260],,0]]],[,-52.895362126290784,176.578125,79.0360206117436,67.171875],2]","1663421298220535",37]],[,[[,"b_al","fs:3377"],[,"b_qu","0"],[,"b_qc","4"]]]]'
	request['x-gwt-cctoken'] = 'ADS25WPi-GfaIIVeBylmuBqbprTRdBzWeCgzxVsE0gV44kxX2oKcTPbuqm0qADNzPjlyjcWQglZmlfjhOR4Y-PM4PrEZny17uJ9QnN0E4a9XQ3EP5UnhTvpDpZNkEglTuRBB-N1mAAB4tlBfcSMgK1v0zosr9k8pxguCjduBPYQPzjxPRCY'
	request['x-gwt-module-base'] = 'https://www.google.com/flights/static/'
	request['x-gwt-permutation'] = 'A282E654365BD08FA0ADED93950EF2D6'
	response = http.request(request)

	body = response.body
	
	#body = File.read('sample.txt')
	if body.include? "302"
		return [nil, false]
	end

	begin
		body.gsub!("\\", "")
		body.gsub!("[,", '["",')
		body.gsub!(",,", ',"",')
		body.gsub!('"ad","', '"ad",')
		body.gsub!('"ad","', '"ad",')
		body.gsub!('","",1]]', ',"",1]]')
		parsed_body = JSON.parse(body)
		
		final_results = []
		results = parsed_body.fetch(1).fetch(0).fetch(2).fetch(3)
		results.each do |result|
			price = result.fetch(4).to_i / 100
			if price > 0
				country = result.fetch(1).fetch(7)
				state = result.fetch(1).fetch(10)
				city = result.fetch(1).fetch(2)
				airport = result.fetch(1).fetch(1)
				image = result.fetch(1).fetch(11)
				final_results.push({"country" => country, "state" => state, "city" => city, "airport" => airport, "image" => image, "price" => price})
			end
		end
		final_results.sort_by! { |r| r["price"]}
		#puts (final_results).inspect
		[final_results, true]

	rescue Error
		[nil, false]
	end

end