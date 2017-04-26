require 'yaml'

#
# Bot configuration.
#
class TriviaConfig
  def initialize
    _config = YAML.load_file(File.join(File.dirname(__FILE__), 'config.yml'))
    @server = _config['server']
    @username = _config['username']
    @password = _config['password']
    @channel = _config['channel']
    @debug = _config['debug']
    @timeout = _config['timeout']
    @activity_timeout = _config['activity_timeout']
  end

  def get_server
    @server
  end

  def get_username
    @username
  end

  def get_password
    @password
  end

  def get_channel
    @channel
  end

  def get_debug
    @debug
  end

  def get_timeout
    @timeout
  end

  def get_activity_timeout
    @activity_timeout
  end
end