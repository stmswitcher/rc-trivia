require_relative 'user'
require_relative 'trivia-config'
require_relative 'scoreboard'

u = User.new
u.login
u.find_channel

#
# Primary class responsible for the game.
#
class Trivia
  #
  # Initialize bot
  #
  def initialize(u)
    # Bot configuration
    @conf = TriviaConfig.new
    # Bot user
    @user = u
    # Bot state
    @active = @conf.get_start_active
    # Scoreboard
    @scoreboard = Scoreboard.new

    # List of questions
    @questions = []
    # List of available topics
    @topics = {}

    # Time before hint could be given
    @hint_time = @conf.get_hint_time

    # Load questions from topic file
    self.load_question
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
  # If topic is not give, random will take place :)
  #
  def load_question(topic = nil)
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

    @user.say ":robot: Topic set to _*#{topic}*_"
    unless @active
      @user.say 'Game is paused. Type !start to resume.'
    end
  end

  #
  # Reset internal pointers
  #
  def reset
    # If the question was asked
    @question_asked = false
    # Time passed since question was asked
    @time_passed = 0
    # Timestamp when question was asked
    @asked_at = 0
    # Answer to the asked question
    @answer = nil
    # When messages were read last time
    @last_read_at = Time.now.strftime('%Y-%m-%dT%H:%M:%S.0Z')
    # Timestamp of the latest users' activity
    @last_activity = Time.now.to_i
  end

  #
  # Ask a question and drop counters
  #
  def ask_question
    @question = @questions.sample
    @answers = @question['answers'].compact
    @answer = @answers.sort_by {|x| x.length}.first.downcase
    @user.say ":question: `#{@question['question']}` :question:"
    @question_asked = true
    @time_passed = 0
    @asked_at = Time.now.to_i
    prepare_hints
  end

  def prepare_hints
    @hints_given = 0
    @hints_available = @answer.length / 3
    @hint = '*' * @answer.length
  end

  #
  # Collects messages from channel,
  # looking for correct answer,
  # handling commands.
  #
  def read
    _messages = @user.read @last_read_at
    _hour = Time.now.hour - 2
    @last_read_at = Time.now.strftime("%Y-%m-%dT#{_hour}:%M:%S.0Z")
    if @active
      @time_passed = Time.now.to_i - @asked_at end

    _messages['messages'].each { |msg|
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
      else
        if @time_passed >= @conf.get_timeout
          _text = 'Time\'s up! The answer was ' + @answer
          @user.say _text
          return true
        end
      end

      unless msg['u']['_id'] == @user.get_user_id
        @last_activity = Time.now.to_i
        unless @active
          @user.say 'Game is paused. Type !start to resume.'
          return true
        end
      end
    }

    if @active
      activity_diff = Time.now.to_i - @last_activity
      if activity_diff >= @conf.get_activity_timeout
        @user.say "No activity for a while. Pausing a game.\nType _!start_ to resume."
        self.pause_game
        return true
      end
    end

    # Give hit if applicable
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
      return self.process_command_rotate
    elsif command =~ /^!topic \w+/
      return self.process_command_rotate_to(command)
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
    if @conf.get_debug
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
  def process_command_rotate
    self.reset
    self.load_question
    true
  end

  #
  # Process !topic <topic> command to change to specified topic.
  #
  def process_command_rotate_to(topic)
    parsed = topic.scan(/!topic (\w+)/)
    if self.load_question(parsed[0][0])
      self.reset
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
    @last_activity = Time.now.to_i
    if @time_passed < @hint_time
      @user.say "#{@hint_time - @time_passed} seconds before hint could be given"
      return
    end

    if @hints_given == @hints_available
      @user.say "No more hints available"
      return
    end

    _chars = @answer.split('')
    _r = rand(@answer.length)
    while @hint[_r] != '*'
      _r = rand(@answer.length) - 1
    end
    @hint[_r] = @answer.split('')[_r]
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

t = Trivia.new(u)

loop do
  if t.get_active
    t.ask_question
  end
  loop do
    if t.read
      break
    else
      sleep 2
    end
  end
  t.get_scoreboard.write_board
  sleep 1
end
