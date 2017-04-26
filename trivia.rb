require_relative 'User'
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
    @active = true
    # Scoreboard
    @scoreboard = Scoreboard.new

    # List of questions
    @questions = []
    # List of available topics
    @topics = {}

    # Load questions from topic file
    self.load_question
    # Reset additional pointers
    self.reset
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
    @answer = @answers.first.downcase
    @user.say ":question: `#{@question['question']}` :question:"
    @question_asked = true
    @time_passed = 0
    @asked_at = Time.now.to_i
  end

  def prepare_hints
    @hints_given = 0
    @hints_available = @answer.length / 3
    @hint = '*' * @answer.length
    puts "Hint: #{@hint}"
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
      if @question['answers'].include? _text.downcase
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
    if command == '!rtv'
      return self.process_command_rotate
    elsif command =~ /^!rtv \w+/
      return self.process_command_rotate_to(command)
    elsif command == '!a'
      return self.process_command_answer
    elsif command == '!commands'
      return self.process_command_commands
    elsif command == '!start'
      return self.process_command_start
    elsif command == '!score'
      return self.process_command_score uid
    else
      @user.say ':robot: Unknown command. Write _!commands_ for list of commands'
    end
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
!rtv - Change topic to random one
!rtv <topic> - Change topic to <topic>
!topics - List available topics
!commands - List of available commands
!start - Start the game```'
    @user.say msg
    false
  end

  #
  # Process !rtv command to change to random topic.
  #
  def process_command_rotate
    self.reset
    self.load_question
    true
  end

  #
  # Process !rtv <topic> command to change to specified topic.
  #
  def process_command_rotate_to(topic)
    parsed = topic.scan(/!rtv (\w+)/)
    if self.load_question(parsed[0][0])
      self.reset
      return true
    end
    false
  end

  #
  # If the enough time passed, gives a hint.
  # The first hint is given after 30 seconds,
  # others - after 15 seconds each.
  #
  # The hint represents *-ed answer string with some letters being shown.
  # @todo implement hints
  #
  def give_hint
    return if @time_passed < 30
    return if @time_passed < 45 and @hints_given == @hints_available
    _chars = @answer.split('')
    _chars.pop
    _r = rand(@answer.length) - 1
    _hints = @hint.split(' ')
    puts "answer: #{@answer}; _chars: #{_chars}; _r: #{_r}; _hints: #{_hints}"
    while _hints[_r] != '*'
      puts _r
      puts _hints[_r]
      sleep 3
      _r = rand(@answer.length) - 1
    end
    _hints[_r] = @answer.split('')[_r]
    @hint = _hints.join(' ')
    @user.say @hint
    @hints_given += 1
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
  sleep 1
end
