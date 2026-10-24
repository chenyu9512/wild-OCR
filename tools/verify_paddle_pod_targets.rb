#!/usr/bin/env ruby
# Verify that CocoaPods post_install has raised every iOS pod target
# to wild-OCR's minimum deployment version before invoking Xcode 27.
require 'xcodeproj'
require 'rubygems'

project_path = ARGV[0] || 'Pods/Pods.xcodeproj'
minimum = Gem::Version.new(ARGV[1] || '17.0')
unless File.directory?(project_path)
  abort("Missing CocoaPods project: #{project_path}; run pod install first")
end

project = Xcodeproj::Project.open(project_path)
invalid = []
inspected = 0

project.targets.each do |target|
  target.build_configurations.each do |configuration|
    inspected += 1
    value = configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
    begin
      version = value && Gem::Version.new(value.to_s)
    rescue ArgumentError
      version = nil
    end
    if version.nil? || version < minimum
      invalid << "#{target.name} / #{configuration.name}: #{value.inspect}"
    end
  end
end

abort('No CocoaPods configurations found') if inspected.zero?

unless invalid.empty?
  warn("ERROR: CocoaPods iOS target below #{minimum} in #{invalid.size} configuration(s):")
  invalid.each { |item| warn(" - #{item}") }
  exit 1
end

puts("PASS: #{inspected} CocoaPods configurations target iOS >= #{minimum}")
%w[Yams OpenCV].each do |name|
  targets = project.targets.select { |target| target.name == name }
  targets.each do |target|
    target.build_configurations.each do |configuration|
      puts("  #{name}/#{configuration.name}: iOS #{configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET']}")
    end
  end
end
