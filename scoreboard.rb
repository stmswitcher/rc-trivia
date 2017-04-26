require 'fileutils'
require 'yaml'

#
# Scoreboard keeps track of users' scores.
#
class Scoreboard
  #
  # Initialize scoreboard.
  #
  def initialize
    @filename = __dir__ + '/scoreboard.yml'

    unless File.file? @filename
      FileUtils.touch @filename
    end

    @scores = YAML.load_file @filename
    unless @scores
      @scores = {}
    end
  end

  #
  # Write scoreboard data to file.
  #
  def write_board
    data = YAML.dump(@scores)
    File.write(@filename, data)
  end

  #
  # Update user's score and maybe a name.
  #
  def give_score(uid, name, score)
    unless @scores.key? uid
      self.init_user_score(uid, 'name')
    end

    @scores[uid]['score'] += score

    unless @scores[uid]['name'] == name
      self.update_user_name uid, name
    end
  end

  #
  # Initialize user score for given user id.
  #
  def init_user_score(uid, name)
    @scores[uid] = {
        'name' => '',
        'score' => 0
    }
    self.update_user_name uid, name
  end

  #
  # Update displayed user name.
  #
  def update_user_name(uid, name)
    @scores[uid]['name'] = name
  end

  #
  # Will return message text with score for user identified by uid.
  #
  def get_user_score_message(uid)
    unless @scores.key? uid
      return 'Unknown user'
    end

    @scores[uid]['name'] + '\'s score is ' + @scores[uid]['score']
  end

end