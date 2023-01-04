
#
# warmaker.rb

VERSION = '1.0.0'.freeze

def print_usage

  puts
  puts "ruby warmaker.rb [options] [fname.war|ROOT.war] [root|.] [tmp_dir]"
  puts
  puts "options:"
  puts "  --dry         : runs dry, not archive creation"
  puts "  --mute        : runs silently"
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

okeys = { 'd' => 'dry', 'm' => 'mute' }
okeys.dup.each { |_, k1| okeys[k1] = k1 }
  #
okeys.each do |k0, k1|
  y["#{k1}?"] = y[k0]
end
okeys.each do |k0, k1|
  y["#{k1}?"] = true if opts.include?(k0)
end

y['dry?'] = true if ENV['DRY']
y['mute?'] = true if ENV['MUTE']


O = OpenStruct.new(y)

wname = args.find { |a| a.match?(/\.war$/) }; args.delete(wname)
O.fname = File.absolute_path(
  wname || O.fname || 'ROOT.war')

O.rootdir = File.absolute_path(
  args.shift || O.rootdir || O.root || '.')

O.tmpdir = File.absolute_path(
  args.shift || O.tmpdir || "war_#{Time.now.strftime('%Y%m%d_%H%M')}")


def echo(s)

  puts(s) unless O.mute?
end


class String

  def absolute?; self.match?(/^\//); end
  def absolute; File.absolute_path(self); end

  def homepath; '~' + self.absolute[Dir.home.length..-1]; end
  alias hpath homepath

  def tpath; (self.absolute[O.tmpdir.length + 1..-1] || '.') + '/'; end
end

class << O

  def tpath(pa)

    pa.absolute? ? pa : File.join(O.tmpdir, pa).absolute
  end

  def rpath(pa)

    pa.absolute? ? pa : File.join(O.rootdir, pa).absolute
  end

  def mkdir!(pa)

    d = self.tpath(pa)
    FileUtils.mkdir_p(d) unless self.dry?
    echo "  #{C.green}. mkdir  #{C.gray(d.hpath)}"
  end

  def copy!(source, target)

    target = target + '/' unless target.match?(/\/$/)

    FileUtils.copy(source, target) unless self.dry?
    echo "    #{C.green}. cp     #{C.gray(source.hpath)} --> #{C.gray(target.tpath)}"
  end

  def copy_dir!(source, target)

    sc = self.rpath(source)
    ta = self.tpath(target)

    self.mkdir!(ta)

    Dir.glob(File.join(sc, '*')).each do |pa1|
      if File.directory?(pa1)
        tdir = File.join(ta, pa1[sc.length + 1..-1])
        self.copy_dir!(pa1, tdir)
      else
        self.copy!(pa1, ta)
      end
    end
  end

  def jar!

    echo "#{C.green}. jar cvf ... TODO"
  end
end

p O

O.mkdir!(O.tmpdir)
  #
O.mkdir.each do |path|
  O.mkdir!(path)
end

O.copy_r.each do |source, target|
  O.copy_dir!(source, target)
end

O.jar!

