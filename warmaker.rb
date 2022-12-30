
#
# warmaker.rb

VERSION = '1.0.0'.freeze

require 'ostruct'
require 'fileutils'

opts, args = ARGV.partition { |a| a.match?(/^-/) }

O = OpenStruct.new

opts.each do |o|
  O[case (k = o.sub(/^-{1,2}/, ''))
    when 'dry' then 'dry?'
    when 'h', 'help' then 'help?'
    when 'v', 'version' then 'version?'
    else "#{k}?"
    end ] = true
end

O.fname = args.find { |a| a.match?(/\.war$/) } || 'ROOT.war'
args.delete(O.fname)

O.root = args.first || '.'
O.root = nil unless File.directory?(O.root)

O.tmp_dir = File.join(O.root, "warmaker_#{Time.now.strftime('%Y%m%d_%H%M%S')}")


if O.help? || O.root.nil?

  puts
  puts "ruby warmaker.rb [options] [fname.war|ROOT.war] [root|.]"
  puts
  puts "options:"
  puts "  --dry         : runs dry, not archive creation"
  puts "  -v|--version  : displays the warmaker version (#{VERSION})"
  puts "  -h|--help     : displays this help information"
  puts

  exit(O.help? ? 0 : 1)
end

if O.version?

  puts "warmaker.rb #{VERSION}"

  exit 0
end

class << O

  def path(pa)

    File.join(self.root, pa)
  end

  def tpath(pa)

    File.join(self.tmp_dir, pa)
  end
end

def copy(path, target_dir)

  puts ". copy  #{path} to #{target_dir}"
end

def mkdir(path)

  puts ". mdkir  #{path}"
end

#
# make tmp_dir

# TODO

#
# copy .html files

Dir[O.path('public/*.html')].each do |pa|

  copy(pa, O.tpath('.'))
end

