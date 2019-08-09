#!/usr/bin/env ruby
#
# NOTE: When it comes time to publish a new version, they must be done
# sequentially and in topological order based on inter-dependencies.
# At the moment, that is:
#
# MobiusCore, MobiusExtras, MobiusTest, MobiusNimble
#
# We must do this as each of these are a separate module and podspecs
# can only define a single module, so we can't do it with subspecs.
#

# Get the current version from git tags
VERSION = begin
  tag = `git describe --abbrev=0 --tags`.strip
  if !$?.success? || tag.empty?
    raise Exception.new('could not get git tag')
  end
  tag.gsub(/^v/, '')
end

# Common Settings
SWIFT_VERSION = '5.0'
IOS_DEPLOYMENT_TARGET = '10.0'
NIMBLE_VERSION = begin
  ver = `cat Cartfile | grep Nimble | grep -o '~.*'`.strip
  if !$?.success? || ver.empty?
    raise Exception.new('could not parse nimble version from Cartfile')
  end
  ver
end

# The base summary added to all specs
BASE_SUMMARY = 'A functional reactive framework for managing state evolution and side-effects'

# These specs need to be in topological order
SPECS = {
  MobiusCore: {
    name: 'MobiusCore',
    source_files: 'MobiusCore/Source/**/*.swift',
    summary: BASE_SUMMARY,
  },

  MobiusExtras: {
    homepage_subdir: 'MobiusExtras',
    source_files: 'MobiusExtras/Source/**/*.swift',
    summary: "#{BASE_SUMMARY}: Extra Helpers",
    dependencies: {
      MobiusCore: [VERSION],
    },
  },

  MobiusTest: {
    homepage_subdir: 'MobiusTest',
    source_files: 'MobiusTest/Source/**/*.swift',
    summary: "#{BASE_SUMMARY}: Test Helpers",
    dependencies: {
      MobiusCore: [VERSION],
    },
    frameworks: ['XCTest'],
  },

  MobiusNimble: {
    homepage_subdir: 'MobiusNimble',
    source_files: 'MobiusNimble/Source/**/*.swift',
    summary: "#{BASE_SUMMARY}: Nimble Helpers",
    dependencies: {
      MobiusCore: [VERSION],
      MobiusTest: [VERSION],
      Nimble: [NIMBLE_VERSION],
    },
    frameworks: ['XCTest'],
  },
}

require 'json'

def generate_all_specs
  for name, spec in SPECS
    spec = spec.dup
    spec[:name] = name
    generate_podspec(**spec)
  end
end

def publish_all_specs
  # check that a trunk session exists
  if !system('pod trunk me >/dev/null 2>&1')
    $stderr.puts "No valid trunk session."
    $stderr.puts "https://guides.cocoapods.org/making/getting-setup-with-trunk"
    exit(1)
  end

  # verify with user (prevent accidental push)
  $stderr.puts "This will push the podspecs in the current directory to CocoaPods trunk"
  $stderr.puts "Version: #{VERSION}"
  $stderr.write 'Continue? (y/n): '
  $stderr.flush
  input = $stdin.gets.chomp.downcase
  exit(1) unless ['y', 'yes'].include?(input)

  # push specs in order
  for spec in SPECS.keys
    puts ''
    file = "#{spec}.podspec.json"
    puts "Pushing #{file}"
    if !system('pod', 'trunk', 'push', file)
      $stderr.puts "error: failed to publish #{spec}"
      exit(1)
    end
    puts ''
  end
end

def generate_podspec(name:, source_files:, summary:, dependencies: [], frameworks: [], homepage_subdir: nil)
  homepage = 'https://github.com/spotify/Mobius.swift'
  homepage = "#{homepage}/tree/master/#{homepage_subdir}" if homepage_subdir

  payload = {
    'name' => name,
    'version' => VERSION,
    'summary' => summary,
    'authors' => 'Spotify AB',
    'homepage' => homepage,
    'social_media_url' => 'https://twitter.com/spotifyeng',
    'license' => {
      'type' => 'Apache 2.0',
      'file' => 'LICENSE'
    },
    'source' => {
      'git' => 'https://github.com/spotify/Mobius.swift.git',
      'tag' => VERSION,
    },
    'platforms' => {
      'ios' => IOS_DEPLOYMENT_TARGET,
    },
    'swift_version' => SWIFT_VERSION,
    'module_name' => name,
    'source_files' => source_files,
  }

  unless frameworks.empty?
    payload['frameworks'] = frameworks.sort
  end

  unless dependencies.empty?
    payload['dependencies'] = dependencies
  end

  File.open("#{name}.podspec.json", 'w') do |fd|
    fd.puts(JSON.pretty_generate(payload))
  end
end

if __FILE__ == $0
  arg = ARGV.first
  if arg == 'generate'
    generate_all_specs
  elsif arg == 'publish'
    publish_all_specs
  else
    $stderr.puts "usage: #{$0} [generate|publish]"
    exit(1)
  end
end
