module InfinityTest
  class Application
    include InfinityTest::TestLibrary
    include InfinityTest::ApplicationLibrary
    include Notifiers
    extend Forwardable

    attr_accessor :config, :watchr, :global_commands

    def_delegator :@config, :rubies, :rubies
    def_delegator :@config, :sucess_image, :sucess_image
    def_delegator :@config, :failure_image, :failure_image
    def_delegator :@config, :pending_image, :pending_image
    def_delegator :@config, :sucess_sound, :sucess_sound
    def_delegator :@config, :failure_sound, :failure_sound
    def_delegator :@config, :pending_sound, :pending_sound    
    def_delegator :@config, :before_callback, :before_callback
    def_delegator :@config, :after_callback, :after_callback
    def_delegator :@config, :before_each_ruby_callback, :before_each_ruby_callback
    def_delegator :@config, :after_each_ruby_callback, :after_each_ruby_callback
    def_delegator :@config, :specific_options, :specific_options
    def_delegator :@config, :verbose, :verbose?
    def_delegator :@config, :notification_framework, :notification_framework
    def_delegator :@config, :skip_bundler?, :skip_bundler?

    # Initialize the Application object with the configuration instance to
    # load configuration and set properly
    #
    def initialize
      @config = InfinityTest.configuration
      @watchr = InfinityTest.watchr
    end

    def load_configuration_file_or_read_the_options!(options)
      load_configuration_file
      setup!(options)
    end

    # Load the Configuration file
    #
    # Command line options can be persisted in a .infinity_test file in a project.
    # You can also store a .infinity_test file in your home directory (~/.infinity_test) with global options.
    #
    # Precedence is:
    # command line
    # ./.infinity_test
    # ~/.infinity_test
    #
    # Example:
    #
    #  ~/.infinity_test -> infinity_test { notifications :growl }
    #
    #  ./.infinity_test -> infinity_test { notifications :lib_notify }  # High Priority
    #
    # After the load the Notifications Framework will be Lib Notify
    #
    def load_configuration_file
      load_global_configuration    # Separate global and local configuration
      load_project_configuration   # because it's more easy to test
    end

    # Run the global commands
    #
    def run_global_commands!
      run!(global_commands)
    end

    # Construct the Global Commands and cache for all suite
    #
    def global_commands
      @global_commands ||= construct_command.create.command
    end
    
    def construct_command
      ConstructCommand.new
    end

    # Return true if the user application has a Gemfile
    # Return false if not exist the Gemfile
    #
    def have_gemfile?
      File.exist?(gemfile)
    end
    
    # Construct all the commands for the changed file
    #
    def construct_commands_for_changed_files(files)
      ConstructCommand.new(:files_to_run => files).create.command
    end

    # Return a instance of the test framework class
    #
    def test_framework
      @test_framework ||= setting_test_framework
    end

    # Return true if the application is using Test::Unit
    # Return false otherwise
    #
    def using_test_unit?
      test_framework.instance_of?(TestUnit)
    end

    # Return a instance of the app framework class
    #
    def app_framework
      @app_framework ||= setting_app_framework
    end

    # Return all the Heuristics of the application
    #
    def heuristics
      config.instance_variable_get(:@heuristics)
    end

    # Triggers the #add_heuristics! method in the application_framework
    #
    def add_heuristics!
      app_framework.add_heuristics!
    end

    def heuristics_users_high_priority!
      @watchr.rules.reverse!
    end
    
    def binary_search(environment)
      test_framework.binary_search(environment)
    end

    # Pass many commands(expecting something that talk like Hash) and run them
    # First, triggers all the before each callbacks, run the commands
    # and last, triggers after each callbacks
    #
    def run!(commands)
      before_callback.call if before_callback

      commands.each do |ruby_version, command|
        call_each_ruby_callback(:before_each_ruby_callback, ruby_version)
        command = say_the_ruby_version_and_run_the_command!(ruby_version, command) # This method exist because it's more easier to test
        notify!(:results => command.results, :ruby_version => ruby_version)
        call_each_ruby_callback(:after_each_ruby_callback, ruby_version)
      end

      after_callback.call if after_callback
    end

    # Send the message, image and the actual ruby version to show in the notification system
    #
    def notify!(options)
      if notification_framework
        message = parse_results(options[:results])
        title = options[:ruby_version]
        send(notification_framework).title(title).message(message).image(image_to_show).sound(sound_to_play).notify! if notification_framework == "growl"
        send(notification_framework).title(title).message(message).image(image_to_show).notify! 
      end
    end

    # Parse the results for each command to the test framework
    #
    # app.parse_results(['.....','108 examples']) # => '108 examples'
    #
    def parse_results(results)
      test_framework.parse_results(results)
    end

    # If the test pass, show the sucess image
    # If is some pending test, show the pending image
    # If the test fails, show the failure image
    #
    def image_to_show
      if test_framework.failure?
        failure_image
      elsif test_framework.pending?
        pending_image
      else
        sucess_image
      end
    end

    # If the test pass, play the sucess sound
    # If is some pending test, play the pending sound
    # If the test fails, play the failure sound
    #
    def sound_to_play
      if test_framework.failure?
        failure_sound
      elsif test_framework.pending?
        pending_sound
      else
        sucess_sound
      end
    end

    def say_the_ruby_version_and_run_the_command!(ruby_version, command)
      puts; puts "* { :ruby => #{ruby_version} }"
      puts command if verbose?
      Command.new(:ruby_version => ruby_version, :command => command).run!
    end

    # Setup over a precendence show below.
    #
    # THIS IS NOT RESPONSABILITY OF Application instances!!!
    #
    def setup!(options)
      rubies_to_use  = options[:rubies] || rubies
      options_to_use = options[:specific_options] || specific_options
      test_framework_to_use = options[:test_framework] || config.test_framework
      framework_to_use = options[:app_framework] || config.app_framework
      use_verbose = options[:verbose] || config.verbose
      config.use(
         :rubies => rubies_to_use,
         :specific_options => options_to_use,
         :test_framework => test_framework_to_use,
         :app_framework => framework_to_use,
         :cucumber => options[:cucumber],
         :verbose => use_verbose)
      config.skip_bundler! if options[:skip_bundler?]
      add_heuristics!
      heuristics_users_high_priority!
    end

    private

    def call_each_ruby_callback(callback_type, ruby_version)
      callback = send(callback_type)
      callback.call(RVM::Environment.new(ruby_version)) if callback
    end

    def setting_test_framework
      case config.test_framework
      when :rspec
        Rspec.new :rubies => rubies, :specific_options => specific_options
      when :test_unit
        TestUnit.new :rubies => rubies, :specific_options => specific_options
      when :bacon
        Bacon.new :rubies => rubies, :specific_options => specific_options
      end
    end

    def setting_app_framework
      case config.app_framework
      when :rails
        Rails.new
      when :rubygems
        RubyGems.new
      end
    end

    def load_global_configuration
      load_file(File.expand_path('~/.infinity_test'))
    end

    def load_project_configuration
      load_file('./.infinity_test')
    end

    def load_file(file)
      load(file) if File.exist?(file)
    end

    def gemfile
      File.join(Dir.pwd, 'Gemfile')
    end

  end
end
