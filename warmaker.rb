
#
# warmaker.rb


VERSION = '1.0.0'.freeze


require 'open3'


def print_usage

  puts
  puts "ruby warmaker.rb [options] [fname.war|ROOT.war] [root|.] [tmp_dir]"
  puts
  puts "options:"
  puts "  --dry            : runs dry, not archive creation"
  puts "  --mute           : runs silently"
  puts "  --nojar|--nowar  : does not create .war in the end"
  puts "  -v|--version     : displays the warmaker version (#{VERSION})"
  puts "  -h|--help        : displays this help information"
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

require 'ostruct'
require 'fileutils'

opts, args = ARGV.partition { |a| a.match?(/^-/) }
opts = opts.collect { |o| o.sub(/^-{1,2}/, '') }

h = {}

okeys = { 'd' => 'dry', 'm' => 'mute', 'nj' => 'nojar' }
okeys.dup.each { |_, k1| okeys[k1] = k1 }
  #
okeys.each do |k0, k1|
  h["#{k1}?"] = h[k0]
end
okeys.each do |k0, k1|
  h["#{k1}?"] = true if opts.include?(k0)
end

h['dry?'] = true if ENV['DRY']
h['mute?'] = true if ENV['MUTE']
h['nojar?'] = true if ENV['NOJAR']


O = OpenStruct.new(h)

wname = args.find { |a| a.match?(/\.war$/) }; args.delete(wname)
O.fname = File.absolute_path(
  wname || O.fname || 'ROOT.war')

O.rootdir = File.absolute_path(
  args.shift || O.rootdir || O.root || '.')

O.tmpdir = File.absolute_path(
  args.shift || O.tmpdir || "war_#{Time.now.strftime('%Y%m%d_%H%M')}")


def echo(s)

  return if O.mute?
  print C.green; print s; puts C.reset
end


class String

  def absolute?; self.match?(/^\//); end
  def absolute; File.absolute_path(self); end

  def homepath; '~' + self.absolute[Dir.home.length..-1]; end
  alias hpath homepath

  def tpath
    tp = self.absolute[O.tmpdir.length + 1..-1] || '.'
    if File.exist?(self)
      tp + (File.directory?(self) ? '/' : '')
    else
      tp + '/'
    end
  end

  def same_path?(s)

    self.absolute == s.absolute
  end
end

#class << O
def tpath(pa)

  pa.absolute? ? pa : File.join(O.tmpdir, pa).absolute
end

def rpath(pa)

  pa.absolute? ? pa : File.join(O.rootdir, pa).absolute
end

def mkdir!(pa)

  d = tpath(pa)

  return if File.exist?(d)

  FileUtils.mkdir_p(d) unless O.dry?

  echo "  . mkdir  #{C.gray(d.hpath)}"
end

def copy_file!(source, target, opts={})

  sc = rpath(source)
  ta = tpath(target)

  mkdir!(ta)

  ta = ta + '/' unless ta.match?(/\/$/)

  if ! File.exist?(sc) && opts[:soft]

    echo "#{C.gray}    . cp     #{sc.hpath} --> #{ta.tpath}"
  else

    FileUtils.copy(sc, ta) unless O.dry?

    echo "    . cp     #{C.gray(sc.hpath)} --> #{C.gray(ta.tpath)}"
  end
end

def copy_file?(source, target, opts={})

  copy_file!(source, target, opts.merge(soft: true))
end

def copy_dir!(source, target, opts={})

  sc = rpath(source)
  ta = tpath(target)
  ex = (opts[:exclude] || []).collect { |e| File.join(sc, e) }

  Dir.glob(File.join(sc, '*')).each do |pa1|

    next if ex.find { |e| pa1.same_path?(e) }

    if File.directory?(pa1)
      tdir = File.join(ta, pa1[sc.length + 1..-1])
      copy_dir!(pa1, tdir)
    else
      copy_file!(pa1, ta)
    end
  end
end

def copy_files!(source, target)

  sc = rpath(source)

  Dir.glob(sc).each do |pa1|
    copy_file!(pa1, target)
  end
end

def copy_config_ru!

  return if Dir[tpath('**/config.ru')].any?

  Dir[rpath('**/config.ru')].take(1).each do |pa|
    copy_file!(pa, 'WEB-INF/')
  end

  echo "  . ensured WEB-INF/config.ru is present"
end

def jruby_version

  @jrv ||= File.read(rpath('.ruby-version')).match(/(\d+\.\d+\.\d+)$/)[1]
end

def gems

  File
    .readlines(rpath('Gemfile.lock'))
    .inject([]) { |a, l|
      m = l.match(/^    ([^\s]+) \(([.0-9]+(-java)?)\)$/)
      a << [ m[1], m[2] ] if m
      a }
end

def gem_path(name, version)

  File.join(
    Dir.home, '.gem/jruby', jruby_version, 'gems', "#{name}-#{version}")
end

def gem_specification_path(name, version)

  File.join(
    Dir.home,
    '.gem/jruby', jruby_version, 'specifications', "#{name}-#{version}.gemspec")
end

def copy_gems!

  gems.each do |name, version|

    copy_dir!(
      gem_path(name, version),
      "WEB-INF/gems/gems/#{name}-#{version}/",
      exclude: %w[
        test/ spec/
        example/ examples/ sample/ samples/
        doc/ docs/
        benchmark/ benchmarks/ bench/
        contrib/
          ])

    copy_file!(
      gem_specification_path(name, version),
      'WEB-INF/gems/specifications/')
  end

  Dir[
    tpath('WEB-INF/gems/gems/**/*.{md,mdown,markdown,rdoc,txt}')
  ].each do |pa|
    next if pa.match(/\/license/i)
    echo "      . rm     #{C.gray(pa)}"
    FileUtils.rm(pa) unless O.dry?
  end
    #
  echo "    . cleaned WEB-INF/gems/"
end

  # |-- jruby-core-9.2.5.0-complete.jar 14M
  # |-- jruby-rack-1.1.21.jar 261K
  # |-- jruby-stdlib-9.2.5.0.jar 10M
  #
def move_jars!

  tp = tpath('WEB-INF/lib/')

  Dir[tpath('WEB-INF/gems/gems/**/jruby-*.jar')].each do |pa|
    system("mv #{pa} #{tp}") unless O.dry?
    echo "      . mv    #{C.gray(pa.hpath)} --> #{C.gray('WEB-INF/lib/')}"
  end

  echo "    . moved jars"
end

def manifest!

  pa = tpath('META-INF/MANIFEST.MF')

  unless O.dry?

    mkdir!('META-INF')

    File.open(pa, 'wb') do |f|
      f.puts "Manifest-Version: 1.0"
      f.puts "Created-By: warmaker.rb #{VERSION}"
    end
  end

  echo "  . wrote  #{C.gray(pa.tpath)}"
end

def jar!

  return if O.nojar?

  FileUtils.rm_f(O.fname) unless O.dry?

  c = "jar --create --file #{O.fname} -C #{O.tmpdir} ."
  system(c) unless O.dry?
  echo ". #{c}"
end

#def sh!(cmd, opts={})
#
#  opts[:chdir] ||= O.rootdir
#
#  _, _, x = Open3.capture3(cmd, opts)
#  x = x.exitstatus
#  echo "  . sh! #{C.dg(cmd)} --> #{C.dg(x)}"
#
#  x == 0
#end


#
# make the .war

mkdir!(O.tmpdir)

mkdir!('WEB-INF')

copy_dir!('public', '.')
#copy_dir!('public', '.', exclude: %w[ test/ ])

copy_file!('Gemfile', 'WEB-INF/')
copy_file!('Gemfile.lock', 'WEB-INF/')
copy_file?('VERSION.txt', 'WEB-INF/')
copy_file?('MIGLEVEL.txt', 'WEB-INF/')

copy_file!('config/web.xml', 'WEB-INF/')
copy_file!(__FILE__.absolute, 'WEB-INF/config/')

#copy_dir!('app', 'WEB-INF/app/')
copy_dir!('app', 'WEB-INF/app/', exclude: %w[ views/ ])

copy_dir!('lib', 'WEB-INF/lib/')

copy_dir!('flor', 'WEB-INF/flor/') # too specific...

copy_file!('fixtures/development/ldap.rb', 'WEB-INF/fixtures/development/')
copy_dir!('pdfs/', 'WEB-INF/pdfs/')

copy_config_ru!

copy_gems!
move_jars!

require rpath('lib/sg/version.rb'); Dir.chdir(O.rootdir) { Sg.dump_versions }
echo "  . dumped #{C.dg}VERSION.txt #{C.gn}and #{C.dg}MIGLEVEL.txt"
copy_file!('VERSION.txt', 'WEB-INF/')
copy_file!('MIGLEVEL.txt', 'WEB-INF/')

manifest!
jar!

