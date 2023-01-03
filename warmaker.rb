
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

module C; class << self
  def reset(s=nil); s ? "[0;0m#{s}[0;0m" : "[0;0m"; end
  def green(s=nil); s ? "[32m#{s}[0;0m" : "[32m"; end
  def dark_gray(s=nil); s ? "[90m#{s}[0;0m" : "[90m"; end
  alias gn green
  alias dg dark_gray
  alias gray dark_gray
end; end

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

y['dry?'] = true if ENV['DRY']


O = OpenStruct.new(y)

wname = args.find { |a| a.match?(/\.war$/) }; args.delete(wname)
O.fname = File.absolute_path(
  wname || O.fname || 'root.war')

O.rootdir = File.absolute_path(
  args.shift || O.rootdir || O.root || '.')

O.tmpdir = File.absolute_path(
  args.shift || O.tmpdir || "warmaker_#{Time.now.strftime('%Y%m%d_%H%M%S')}")


class String

  def absolute?; self.match?(/^\//); end
end

class << O

  def tpath(pa)

    pa.absolute? ? pa : File.join(O.tmpdir, pa)
  end

  def rpath(pa)

    pa.absolute? ? pa : File.join(O.rootdir, pa)
  end

  def relpath(pa)

    pa[O.rootdir.length + 1..-1]
  end

  def mkdir!(pa)

    d = self.tpath(pa)
    FileUtils.mkdir_p(d) unless self.dry?
    puts "  #{C.green}. mkdir  #{C.gray}#{d}#{C.reset}"
  end

  def copy_dir!(pa)

    Dir[File.join(self.rpath(pa), '*')].each do |pa1|
      if File.directory?(pa1)
        p [ :dir, pa1, self.relpath(pa1) ]
      else
        p pa1
      end
    end
  end
end

p O

O.mkdir!(O.tmpdir)
  #
O.mkdir.each do |path|
  O.mkdir!(path)
end

O.copy_r.each do |path|
  O.copy_dir!(path)
end


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

