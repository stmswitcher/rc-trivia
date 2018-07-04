require_relative 'user'
require_relative 'trivia-config'
require_relative 'scoreboard'

$config = TriviaConfig.new

def debug (msg)
  puts msg if $config.get_debug
end

user = User.new
user.login
user.find_channel

#
# Primary class responsible for the game.
#
class Trivia
  #
  # Initialize bot
  #
  def initialize(user)
    @user = user
    # Bot state
    @active = $config.get_start_active
    # Scoreboard
    @scoreboard = Scoreboard.new

    # List of questions
    @questions = []
    # List of available topics
    @topics = {}

    # Time before hint could be given
    @hint_time = $config.get_hint_time

    # Load questions from topic file
    self.load_questions
    # Reset additional pointers
    self.reset
  end

  #
  # Scoreboard accessor.
  #
  def get_scoreboard
    @scoreboard
  end

  #
  # Collect questions for specified topic from file.
  #
  # If topic is not given, it will be set randomly.
  #
  def load_questions(topic = nil)
    _path = File.dirname(__FILE__) + '/questions/'

    unless File.directory?(_path)
      puts 'Unable to find questions'
      exit 1
    end

    _files = Dir[_path + '*.txt']
    _files.each { |file|
      @topics[File.basename(file, '.txt')] = file
    }

    if @topics.empty?
      puts 'No questions found'
      exit 1
    end

    if topic.nil? or !@topics.key?(topic)
      unless topic.nil?
        @user.say ':robot: _Unknown topic_'
        return false
      end

      topic = @topics.keys.sample
    end

    @questions = []
    File.readlines(@topics[topic]).each { |line|
      _q, *_a = line.split('`')
      next if _a.first.nil?
      _pp = _a.first.strip
      _a << _pp
      @questions << {
          'question' => _q,
          'answer' => _pp,
          'answers' => _a.compact.map{|a|
            a.downcase.strip
          }
      }
    }

    if @active
      @user.say ":robot: Topic set to _*#{topic}*_"
    elsif
      @user.say 'Game is paused. Type !start to resume.'
      return false
    end
  end

  #
  # Reset internal pointers
  #
  def reset
    # If the question was asked
    @question_asked = false
    # Time passed since question was asked (system clock)
    @time_passed = 0
    # Timestamp when question was asked (system time)
    @asked_at = 0
    # Answer to the asked question
    @answer = nil
    # Timestamp of the latest users' activity (remote clock)
    @last_activity = nil
  end

  #
  # Ask a question and drop counters.
  #
  def ask_question
    @question = @questions.sample
    @answers = @question['answers'].compact
    @answer = @answers.sort_by {|x| x.length}.first.downcase

    debug @answer

    _response = @user.say ":question: `#{@question['question']}` :question:"

    @asked_at = Time.now.to_i

    # If @last_activity was never set before, set it to the time of first question
    unless @last_activity
      @last_activity = Time.parse(_response['message']['ts'])
    end

    @question_asked = true
    prepare_hints
  end

  #
  # Initialize hint.
  #
  def prepare_hints
    @hints_given = 0
    @hints_available = [@answer.length / 3, @answer.split('').uniq.length].min
    @hint = '*' * @answer.length
    # Letters that are already uncovered
    @hint_letters = []
  end

  #
  # Collects messages from channel,
  # looking for correct answer,
  # handling commands.
  #
  # Method returns true in case if next question has to be asked,
  # false if game has to continue.
  #
  def read
    _messages = @user.read @last_activity.strftime("%Y-%m-%dT%H:%M:%S.0Z")

    _messages = _messages['messages'].select{|item|
      Time.parse(item['ts']).to_i > @last_activity.to_i and item['u']['_id'] != @user.get_user_id
    }
    if _messages.any?
      @last_activity = Time.parse(_messages.first['ts'])
    end

    if @active
      @time_passed = Time.now.to_i - @asked_at
    end

    _messages.each { |msg|
      _text = msg['msg']

      if _text.split('').first == '!'
        return self.process_command _text, msg['u']['_id']
      end

      # If correct answer given
      if @active and @question['answers'].include? _text.downcase
        self.reset
        _win_text = ':boom: @' + msg['u']['username'] + ' wins this round! :boom: (The answer is _' + @question['answer'] + '_)'
        @scoreboard.give_score msg['u']['_id'], msg['u']['username'], 1
        @user.say _win_text
        @user.say @scoreboard.get_user_score_message msg['u']['_id']
        return true
      end
    }

    if @time_passed >= $config.get_timeout
      _text = 'Time\'s up! The answer was ' + @answer
      @user.say _text
      return true
    end

    if @active and @time_passed >= $config.get_activity_timeout
        @user.say "No activity for a while. Pausing a game.\nType _!start_ to resume."
        self.pause_game
        return true
    end

    if _messages.any? and not @active
      @user.say 'Game is paused. Type !start to resume.'
      return true
    end

    # Give hit if applicable @todo
    #self.give_hint

    false
  end

  #
  # Pause the game.
  #
  def pause_game
    @time_passed = 0
    @active = false
  end

  #
  # Resume the game.
  #
  def resume_game
    self.reset
    @active = true
  end

  #
  # Process commands.
  #
  def process_command(command, uid)
    if command == '!topic'
      return self.process_command_topic
    elsif command =~ /^!topic \w+/
      return self.process_command_change_topic(command)
    elsif command == '!a'
      return self.process_command_answer
    elsif command == '!commands'
      return self.process_command_commands
    elsif command == '!start'
      return self.process_command_start
    elsif command == '!score'
      return self.process_command_score uid
    elsif command == '!topics'
      return self.process_command_topics
    elsif command == '!hint'
      return self.give_hint
    else
      @user.say ':robot: Unknown command. Write _!commands_ for list of commands'
    end
    false
  end

  #
  # Process command to show list of available topics.
  #
  def process_command_topics
    msg = ''
    @topics.each { |topic|
      msg += "#{topic.first}\r\n>"
    }
    @user.say msg
    false
  end

  #
  # Process command to show user's score.
  #
  def process_command_score(uid)
    @user.say @scoreboard.get_user_score_message uid
    false
  end

  #
  # Process command to resume the game.
  #
  def process_command_start
    if @active
      return false
    end

    @user.say 'Resuming the game.'
    self.resume_game
    true
  end

  #
  # Write answer to chat.
  #
  def process_command_answer
    if $config.get_debug
      @user.say @answer
    end
    false
  end

  #
  # Display all available commands.
  #
  def process_command_commands
    msg = '```
!topic - Change topic to random one
!topic <topic> - Change topic to <topic>
!topics - List available topics
!commands - List of available commands
!start - Start the game
!hint - Give a hint```'
    @user.say msg
    false
  end

  #
  # Process !topic command to change to random topic.
  #
  def process_command_topic
    self.reset
    self.load_questions
    true
  end

  #
  # Process !topic <topic> command to change to specified topic.
  #
  def process_command_change_topic(topic)
    parsed = topic.scan(/!topic (\w+)/)
    if self.load_questions(parsed[0][0])
      self.reset
      sleep 1
      return true
    end
    false
  end

  #
  # If enough time has passed, gives a hint.
  #
  # The hint represents *-ed answer string with some letters being shown.
  #
  def give_hint
    if @time_passed < @hint_time
      @user.say "#{@hint_time - @time_passed} seconds before hint could be given"
      return
    end

    if @hints_given == @hints_available
      @user.say "No more hints available"
      return
    end

    _position = rand(@answer.length)
    while @hint[_position] != '*' and not @hint_letters.include? @answer.split('')[_position]
      _position = rand(@answer.length)
    end
    @hint = ''
    @hint_letters.push @answer.split('')[_position]
    @answer.split('').each { | letter |
      if @hint_letters.include? letter
        @hint = @hint + letter
      else
        @hint = @hint + '*'
      end
    }
    @user.say " :spy: `#{@hint}`"
    @hints_given += 1
    false
  end

  #
  # Get active state of the bot.
  #
  def get_active
    @active
  end
end

game = Trivia.new(user)

loop do
  if game.get_active
    game.ask_question
  end
  loop do
    if game.read
      break
    else
      sleep 2
    end
  end
  game.get_scoreboard.write_board
  sleep 2
end
