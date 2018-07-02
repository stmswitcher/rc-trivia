require 'json'
require 'rest-client'

#
# Bot user.
#
class User
  def initialize
    @channel_id
    @auth_token
    @user_id
    if $config.get_debug
      RestClient.log = 'stdout'
    end
  end

  #
  # Sign user in.
  #
  # This method will set user auth token and user id.
  #
  def login
    debug 'Trying to login'
    _response = self.signed_request '/api/v1/login', 'POST', {
        user: $config.get_username,
        password: $config.get_password
    }

    if _response['status'] != 'success'
      puts 'Unable to login!'
      exit 1
    else
      debug 'Signed in successfully'
    end

    @auth_token = _response['data']['authToken']
    @user_id = _response['data']['userId']
  end

  #
  # Make a signed request.
  #
  # Will return JSON response.
  #
  def signed_request(uri, method, data = {})
    _user_info = {'X-Auth-Token' => @auth_token, 'X-User-Id' => @user_id}
    _url = $config.get_server + uri

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

  #
  # Look for an existing game channel.
  # If channel is not found, we'll try to create one.
  #
  def find_channel
    debug 'Looking for channel...'
    _response = self.signed_request'/api/v1/channels.list.joined', 'GET'
    _channels = _response['channels']

    _channels.each { |ch|
      if ch['name'] == $config.get_channel
        @channel_id = ch['_id']
        break
      end
    }

    if @channel_id
      debug "Channel found! Channel ID is #{@channel_id}"
    else
      puts "Channel not found. Check if channel ##{$config.get_channel} exists and bot user is added to the channel."
      exit 1
    end
  end

  #
  # Say something into chat.
  #
  def say(msg)
    self.signed_request '/api/v1/chat.postMessage', 'POST', {roomId: @channel_id, text: '>' + msg}
  end

  #
  # Read channel messages.
  #
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