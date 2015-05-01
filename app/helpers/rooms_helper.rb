module RoomsHelper
	require 'google/api_client'
	require 'json'
	require 'wikipedia'
	require 'net/http'
	require 'open-uri'
	require 'fileutils'
	require 'nokogiri'

	include ScheduleHelper

	WolframAPIKey = YAML.load_file("#{::Rails.root}/config/wolfram.yml")[::Rails.env]

	def redirect_user
		url_string = request.original_url
		url_array = url_string.split('/')
		url_index = 0;

		while url_index < url_array.size
			if url_array[url_index] == 'room'
				url_index += 1
				break
			end
		url_index += 1
		end

		if url_array[url_index].to_i.to_s == url_array[url_index]
			if Group.where(id: url_array[url_index].to_i, group_name: url_array[url_index + 1]).empty?
				flash[:danger] = 'This group does not exist. Create a group in the sidebar to the left and join its room.'
				redirect_to chat_path
			elsif Relationship.where(group_id: url_array[url_index].to_i, user_id: current_user.id).empty?
				flash[:danger] = 'You are not a member of this group. You must be invited to the group in order to join this room.'
				redirect_to chat_path
			end
		end
	end


##############################################################################################################
##############################################################################################################
##############################################################################################################
##############################################################################################################

									#API CODE!  ADD STUFF HERE PLEASE

##############################################################################################################
##############################################################################################################
##############################################################################################################
##############################################################################################################

	def choose_api(json)
		json_hash = JSON.parse(json)
		logger.info json_hash['api_type']

		case json_hash['api_type']
		when 'calendar'
			logger.info "We will access the calendar api!"
			json_event = calendar_json(json_hash)
			create_calendar_event(json_event)
		when 'calendar_show'
			puts "We will show the calendar"
			#json_event = calendar_show_json(json_hash)
		when 'schedule_suggest'
			logger.info 'We will find a time that works'
			json_event = schedule_json(json_hash)
		when 'google_docs'
			puts "We will access the google docs api!"
		when 'wolfram'
			puts "We will access the wolfram alpha api!"
			query_wolfram_alpha(json_hash)
		when 'youtube'
			logger.info "We will access the youtube api!"
		when 'wikipedia'
			logger.info "We will access the wikipedia api!"
			query_wikipedia(json_hash)
		else
			"NOTHING HAPPENED!?!?!?!?!??!?!??!?!"
		end
	end

	def query_wolfram_alpha(json_hash)
		coder = HTMLEntities.new
		query_string = json_hash['query'].to_s
		query_string = query_string.split(" '").join
		query_string = query_string.split("'").join
		puts "&&&&&&&&&&&&&&&&: " + query_string
		app_id = WolframAPIKey["app_id"]
		wolfram_url = URI.parse("http://api.wolframalpha.com/v2/query?appid=P3P4W5-LGWA2A3RU2&input=" + URI.encode(query_string.strip) + "&format=html,image").to_s

		puts "@@@@@@@@@@@@wolfram url: " + wolfram_url
		doc = Nokogiri::XML(open(wolfram_url))

		# check to see if the freakin pods exist in the wolfram. if yes, then make 
		# JSON object out of wolfram_html, but add the attribute "valid: yes/no" 

		# <queryresult success='false' OR # <pod title='Definition' means we should do wiki instead of wolfram
		api_html = ""
		real_api_type = ""
		# if doc.xpath("//queryresult").attr("success").to_s == 'false' or doc.xpath('//*[@title="Definition"]').length != 0
			# get wiki hash
			#real_api_type = "wikipedia"
			#wikihash = query_wikipedia(json_hash)
			# return relevant html for wiki somehow by setting api_html in redis to the right stuff
		# otherwise the api type is definitely wolfram
		# else
			# grab the wolfram html
			real_api_type = "wolfram"
			markups = []
			doc.xpath("//markup").each do |markup|
				markups << markup.text
			api_html = markups.join.to_s.split('"').join("'")
			api_html = api_html.split("\n").join()
			# api_html.gsub! 'http://',''
		#end
			end
			puts "@@@@@@@@@@@@@@@@@@@html" + api_html
			puts "@@@@@@@@@@@@@@@@@@@real_api_type" + real_api_type
			# store wolfram or wiki api_html in redis
			$redis.set("#{current_user.id}:api_html",api_html.to_s)
			$redis.set("#{current_user.id}:real_api_type", real_api_type)
	end


	def query_wikipedia(json_hash)
		page = Wikipedia.find( json_hash['query'] )
		wiki_hash = Hash.new
		wiki_hash['title'] = page.title
		wiki_hash['content'] = page.content
		wiki_hash['categories'] = page.categories
		wiki_hash['links'] = page.links
		wiki_hash['extlinks'] = page.extlinks
		wiki_hash['images'] = page.images
		wiki_hash['image_urls'] = page.image_urls
		wiki_hash['image_descriptionurls'] = page.image_descriptionurls
		wiki_hash['coordinates'] = page.coordinates
		wiki_hash['templates'] = page.templates

		puts wiki_hash
		wiki_hash
	end

end
