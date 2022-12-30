
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

O.fname =
  args.find { |a| a.match?(/\.war$/) } ||
  'ROOT.war'
args.delete(O.fname)

O.conf =
  args.find { |a| a.match?(/\.ya?ml$/) } ||
  File.join(__dir__, 'warmaker.yaml')
args.delete(O.conf)
O.conf = YAML.load(File.read(O.conf))

O.root = File.absolute_path(args.shift || '.')
O.root = nil unless File.directory?(O.root)

O.tmp_dir =
  args.shift ||
  File.join(O.root, "warmaker_#{Time.now.strftime('%Y%m%d_%H%M%S')}")
O.tmp_dir =
  File.absolute_path(O.tmp_dir)


if O.help? || O.root.nil?

  puts
  puts "ruby warmaker.rb [options] [fname.war|ROOT.war] [root|.] [tmp_dir]"
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


#
# do it...

class << O

  def path(pa)

    File.join(self.root, pa)
  end

  def tpath(pa)

    File.join(self.tmp_dir, pa)
  end

  alias full_path path
  alias full_tpath tpath

  def short_path(pa)

    pa1 = pa.match?(/^\//) ? pa : self.path(pa)

    pa1[self.root.length + 1..-1]
  end

  def short_tpath(pa)

    pa1 = pa.match?(/^\//) ? pa : self.tpath(pa)

    pa1[self.tmp_dir.length + 1..-1]
  end

  #def glob(pa)
  #  Dir.glob(self.full_path(pa))
  #end
end

def copy(path, target_dir)

  #puts ". copy   #{path} to #{target_dir}"
  puts ". copy   #{O.short_path(path)} to #{target_dir}"
end

#def copy_r(path, target_dir)
#  puts ".copy_r  #{path} to #{target_dir}"
#end

def mkdir(path)

  puts ". mdkir  #{path}"
end


# TODO mix conf

pp O.conf

