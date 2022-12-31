
#
# warmaker.rb

VERSION = '1.0.0'.freeze

def print_usage

  puts
  puts "ruby warmaker.rb [options] [fname.war|ROOT.war] [root|.] [tmp_dir]"
  puts
  puts "options:"
  puts "  --dry         : runs dry, not archive creation"
  puts "  -v|--version  : displays the warmaker version (#{VERSION})"
  puts "  -h|--help     : displays this help information"
  puts
end

if ARGV.include?('-h') || ARGV.include?('--help')
  print_usage
  exit 0
end

if ARGV.include?('-v') || ARGV.include?('--version')
  puts "warmarker.rb #{VERSION}"
  exit 0
end

require 'yaml'
require 'ostruct'
require 'fileutils'

opts, args = ARGV.partition { |a| a.match?(/^-/) }
opts = opts.collect { |o| o.sub(/^-{1,2}/, '') }

y = YAML.load_file(File.join(__dir__, 'warmaker.yaml'))

y1 = args.find { |a| a.match?(/\.ya?ml$/) }; args.delete(y1)
y1 = YAML.load_file(y1) if y1

(y1 || {}).each do |k, v|
  if k.match?(/!$/)
    y[k[0..-2]] = v
  else
    v0 = y[k]
    case [ v0.class, v.class ]
    when [ Hash, Hash ] then v0.merge(v)
    when [ Array, Array ] then v0.append(*v)
    else y[k] = v
    end
  end
end

okeys = { 'd' => 'dry', }
okeys.dup.each { |_, k1| okeys[k1] = k1 }
  #
okeys.each do |k0, k1|
  y["#{k1}?"] = y[k0]
end
okeys.each do |k0, k1|
  y["#{k1}?"] = true if opts.include?(k0)
end

O = OpenStruct.new(y)

class << O

  def abs(path)

    path.match?(/^\//) ?
      path :
      File.absolute_path(File.join(self.root, path))
  end
end

wname = args.find { |a| a.match?(/\.war$/) }; args.delete(wname)
O.fname = File.absolute_path(wname || O.fname || 'root.war')

O.root = File.absolute_path(args.shift || O.root || '.')

O.tmpdir = O.abs(
  args.shift ||
  O.tmpdir ||
  "warmaker_#{Time.now.strftime('%Y%m%d_%H%M%S')}")

p O

#class << O
#
##  def path(pa)
##
##    File.join(self.root, pa)
##  end
##
##  def tpath(pa)
##
##    File.join(self.tmp_dir, pa)
##  end
##
##  alias full_path path
##  alias full_tpath tpath
##
##  def short_path(pa)
##
##    pa1 = pa.match?(/^\//) ? pa : self.path(pa)
##
##    pa1[self.root.length + 1..-1]
##  end
##
##  def short_tpath(pa)
##
##    pa1 = pa.match?(/^\//) ? pa : self.tpath(pa)
##
##    pa1[self.tmp_dir.length + 1..-1]
##  end
##
#  #def glob(pa)
#  #  Dir.glob(self.full_path(pa))
#  #end
#end
#
##def copy(path, target_dir)
##  #puts ". copy   #{path} to #{target_dir}"
##  puts ". copy   #{O.short_path(path)} to #{target_dir}"
##end
#
##def copy_r(path, target_dir)
##  puts ".copy_r  #{path} to #{target_dir}"
##end
#
##def mkdir(path)
##
##  puts ". mdkir  #{path}"
##end

