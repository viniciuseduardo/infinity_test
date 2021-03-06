require 'infinity_test/dependencies'

module InfinityTest
  
  autoload :Application, 'infinity_test/application'
  autoload :ApplicationFile, 'infinity_test/application_file'
  autoload :BinaryPath, 'infinity_test/binary_path'
  autoload :Command, 'infinity_test/command'
  autoload :Configuration, 'infinity_test/configuration'
  autoload :ConstructCommand, 'infinity_test/construct_command'
  autoload :ContinuousTesting, 'infinity_test/continuous_testing'
  autoload :Environment, 'infinity_test/environment'
  autoload :Heuristics, 'infinity_test/heuristics'
  autoload :HeuristicsHelper, 'infinity_test/heuristics_helper'
  autoload :Generator, 'infinity_test/generator'
  autoload :Notification, 'infinity_test/notification'
  autoload :Options, 'infinity_test/options'
  autoload :Runner, 'infinity_test/runner'
  autoload :Setup, 'infinity_test/setup'
  autoload :TestFramework, 'infinity_test/test_framework'

  module ApplicationLibrary
    autoload :Rails , 'infinity_test/application_library/rails'
    autoload :RubyGems, 'infinity_test/application_library/rubygems'
  end

  module TestLibrary
    autoload :Bacon, 'infinity_test/test_library/bacon'
    autoload :Cucumber, 'infinity_test/test_library/cucumber'
    autoload :Rspec, 'infinity_test/test_library/rspec'
    autoload :TestUnit, 'infinity_test/test_library/test_unit'
  end

  def self.application
    @application ||= Application.new
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.watchr
    @watchr ||= Watchr::Script.new
  end
  
  def self.runner
    @runner ||= Runner.new(ARGV)
  end

  def self.start!
    runner.run!
  end
  
  def self.version
    version = YAML.load_file(File.dirname(__FILE__) + '/../VERSION.yml')
    [version[:major], version[:minor], version[:patch]].compact.join(".")    
  end

end
