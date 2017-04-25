require 'json'
require 'rest-client'
require_relative 'trivia-config'

class User
  def initialize
    _conf = TriviaConfig.new
    @username = _conf.get_username
    @password = _conf.get_password
    @server = _conf.get_server
    @channel = _conf.get_channel
    @channel_id
    if _conf.get_debug
      RestClient.log = 'stdout'
    end
  end

  # Sign in user
  #
  # This method will save user auth token and user id
  def login
    puts 'Trying to login'
    _response = self.signed_request '/api/v1/login', 'POST', {user: @username, password: @password}

    if _response['status'] != 'success'
      puts 'Unable to login!'
      exit(1)
    else
      puts 'Signed in successfully'
    end

    @auth_token = _response['data']['authToken']
    @user_id = _response['data']['userId']
  end

  # Make a signed request
  def signed_request(uri, method, data = {})
    _user_info = {'X-Auth-Token' => @auth_token, 'X-User-Id' => @user_id}
    _url = @server + uri

    if method == 'POST'
      _response = RestClient.post(_url, data, _user_info)
    else
      _url = _url + '?' + data.map{ |key, value|
        "#{key}=#{value}"
      }.join('&')

      _response = RestClient.get(_url, _user_info)
    end

    JSON.parse(_response)
  end

  def find_channel
    puts 'Looking for channel...'
    _response = self.signed_request'/api/v1/channels.list', 'GET'
    _channels = _response['channels']

    _channels.each { |ch|
      if ch['name'] == @channel
        @channel_id = ch['_id']
        break
      end
    }

    if @channel_id
      puts "Channel found! Channel ID is #{@channel_id}"
    else
      puts 'Channel not found. Creating one...'
      self.create_channel
    end

    puts 'Joining the channel...'
    #_response = self.signed_request '/api/v1/channels.open', 'POST', {roomId: @channel_id}

    if _response['status'] != 'success'
      puts 'Unable to join the channel. Whatever...'
    end
  end

  def create_channel
    _response = self.signed_request'/api/v1/channels.create', 'POST', {name: @channel}

    if _response['status'] == 'success'
      @channel_id = _response['channel']['_id']
      puts "Channel created! Channel ID is #{@channel_id}"
    else
      puts 'Could not create channel!'
      exit 1
    end
  end

  def say(msg)
    self.signed_request '/api/v1/chat.postMessage', 'POST', {roomId: @channel_id, text: '>' + msg}
  end

  def read(since)
    self.signed_request '/api/v1/channels.history', 'GET', {
        'roomId' => @channel_id,
        'oldest' => since,
        'count' => 10
    }
  end

  #
  # Get user ID.
  #
  def get_user_id
    @user_id
  end
end