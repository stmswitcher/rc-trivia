# Trivia game bot for Rocket Chat

This bot is using Rocket Chat's REST API and lets users in certain room to play trivia game.

The idea comes from IRC trivia game.

### The game

Users in chat room are being asked a question, first user that gives correct answer will gain points. Then new question is being asked.

### Requirements

Gems: `rest-client daemons`.

There's no special requirements for this bot, except that you need Ruby installed. Since bot is using REST API, you don't even need your own Rocket Chat server, just point the bot to the server you like by setting corresponding server value.

_Please, don't use the bot for abusing purposes._

However, it'd be better to create bot user account for your server to make it clear that the game is being operated by bot user. Refer to [Rocket Chat documentation](https://rocket.chat/docs/bots/) on how to do it.

### Configuration

Configuration file example has all possible settings, copy _config.yml.example_ into _config.yml_ in the same folder and put desired values:

* **server** - URL of Rocket Chat you'd like to connect to (_ex. http://chat.example.com, http://localhost:3000_). **Don't use trailing slash!**
* **username** and **password** - credentials of user that will operate the game.
* **channel** - name of the channel in which the game will take place.
* **debug** - Debug mode, if enabled, will print request information into STDOUT.
* **timeout** - Time in seconds, after which it's considered that none of the users were able to give a right answer to the question. In this case, the right answer will be shown and next question asked.
* **activity_timeout** - Time in seconds, after which it's considered that there's no active users at the moment and bot will suspend untill `!start` command is given. This is dont to avoid spamming in the channel when no game in progress.
* **start_active** - Start the game immediately when the bot has started, otherwise, it takes to give bot `!start` command to start the game.
* **hint_time** - Time in seconds, after which it's allowed to give a hint to the current question.

### Starting the bot

    $ ruby trivia.rb
or run as a daemon:
    
    $ ruby trivia-bot.rb start

### Commands

Chat bot may process certain _commands_:

* `!start` - start the game if it's not in progress
* `!topic` - switch topic of the game to random one
* `!topic <topicname>` - switch topic of the game to the given one
* `!topics` - list available topics
* `!commands` - lists available commands
* `!score` - will reply with user's score
* `!hint` - gives a hint to current question

### Structure of questions files

There's a `questions` folder that contains multiple _txt_ files.
Each of these files represent certain topic, where filename is being the topic.

Every single line in every of those files represents single question.
Every question is followed by one or many answer variants separated by _`_.

### Credits

This project was created at the first internal Hackathon at [About You Tech](https://medium.com/about-developer-blog).

Questions in this repository were taken from open sources.

#### _P.S._

I'm not a Ruby developer. In fact, it was my first Ruby project. PRs and comments are warmly welcome.

Also, feel free to contribute your questions.
