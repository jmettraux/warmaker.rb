
#
# warmaker.rb

VERSION = '1.0.0'.freeze

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

class << O

  def tpath(pa)

    pa.absolute? ? pa : File.join(O.tmpdir, pa).absolute
  end

  def rpath(pa)

    pa.absolute? ? pa : File.join(O.rootdir, pa).absolute
  end

  def mkdir!(pa)

    d = self.tpath(pa)

    return if File.exist?(d)

    FileUtils.mkdir_p(d) unless self.dry?

    echo "  . mkdir  #{C.gray(d.hpath)}"
  end

  def copy_file!(source, target, opts={})

    sc = self.rpath(source)
    ta = self.tpath(target)

    self.mkdir!(ta)

    ta = ta + '/' unless ta.match?(/\/$/)

    if ! File.exist?(sc) && opts[:soft]

      echo "#{C.gray}    . cp     #{sc.hpath} --> #{ta.tpath}"
    else

      FileUtils.copy(sc, ta) unless self.dry?

      echo "    . cp     #{C.gray(sc.hpath)} --> #{C.gray(ta.tpath)}"
    end
  end

  def copy_file?(source, target, opts={})

    self.copy_file!(source, target, opts.merge(soft: true))
  end

  def copy_dir!(source, target, opts={})

    sc = self.rpath(source)
    ta = self.tpath(target)
    ex = (opts[:exclude] || []).collect { |e| File.join(sc, e) }

    Dir.glob(File.join(sc, '*')).each do |pa1|

      next if ex.find { |e| pa1.same_path?(e) }

      if File.directory?(pa1)
        tdir = File.join(ta, pa1[sc.length + 1..-1])
        self.copy_dir!(pa1, tdir)
      else
        self.copy_file!(pa1, ta)
      end
    end
  end

  def copy_config_ru!

    return if Dir[O.tpath('**/config.ru')].any?

    Dir[O.rpath('**/config.ru')].take(1).each do |pa|
      self.copy_file!(pa, 'WEB-INF/')
    end

    echo "  . ensured WEB-INF/config.ru is present"
  end

  def jruby_version

    @jrv ||=
      File.read(self.rpath('.ruby-version')).match(/(\d+\.\d+\.\d+)$/)[1]
  end

  def gems

    File
      .readlines(self.rpath('Gemfile.lock'))
      .inject([]) { |a, l|
        m = l.match(/^    ([^\s]+) \(([.0-9]+(-java)?)\)$/)
        a << [ m[1], m[2] ] if m
        a }
  end

  def gem_path(name, version)

    File.join(
      Dir.home, '.gem/jruby', jruby_version, 'gems', "#{name}-#{version}")
  end

  def copy_gems!

    self.gems.each do |name, version|

      self.copy_dir!(
        self.gem_path(name, version),
        "WEB-INF/gems/gems/#{name}-#{version}/",
        exclude: %w[
          test/ spec/
          example/ examples/ sample/ samples/
          doc/ docs/
          benchmark/ benchmarks/ bench/
          contrib/
            ])
    end

    Dir[
      O.tpath('WEB-INF/gems/gems/**/*.{md,mdown,markdown,rdoc,txt}')
    ].each do |pa|
      next if pa.match(/\/license/i)
      echo "      . rm     #{C.gray(pa)}"
      FileUtils.rm(pa) unless self.dry?
    end
      #
    echo "    . cleaned WEB-INF/gems/"
  end

    # |-- jruby-core-9.2.5.0-complete.jar 14M
    # |-- jruby-rack-1.1.21.jar 261K
    # |-- jruby-stdlib-9.2.5.0.jar 10M
    #
  def move_jars!

    tp = O.tpath('WEB-INF/lib/')

    Dir[O.tpath('WEB-INF/gems/gems/**/jruby-*.jar')].each do |pa|
      system("mv #{pa} #{tp}") unless self.dry?
      echo "      . mv    #{C.gray(pa.hpath)} --> #{C.gray('WEB-INF/lib/')}"
    end

    echo "    . moved jars"
  end

  def manifest!

    pa = self.tpath('META-INF/MANIFEST.MF')

    unless self.dry?

      self.mkdir!('META-INF')

      File.open(pa, 'wb') do |f|
        f.puts "Manifest-Version: 1.0"
        f.puts "Created-By: warmaker.rb #{VERSION}"
      end
    end

    echo "  . wrote  #{C.gray(pa.tpath)}"
  end

  def jar!

    return if self.nojar?

    FileUtils.rm_f(self.fname) unless self.dry?

    c = "jar --create --file #{self.fname} -C #{self.tmpdir} ."
    system(c) unless self.dry?
    echo ". #{c}"
  end
end


#
# make the .war

O.mkdir!(O.tmpdir)

O.mkdir!('WEB-INF')

#O.copy_dir!('public', '.', exclude: %w[ test/ ])

O.copy_file!('webinf/web.xml', 'WEB-INF/')

O.copy_file!('Gemfile', 'WEB-INF/')
O.copy_file!('Gemfile.lock', 'WEB-INF/')
O.copy_file?('VERSION.txt', 'WEB-INF/')
O.copy_file?('MIGLEVEL.txt', 'WEB-INF/')
O.copy_file!(__FILE__.absolute, 'WEB-INF/config/')
  # TODO second file in WEB-INF/config/ ???

#O.copy_dir!('app', 'WEB-INF/app/')
O.copy_dir!('app', 'WEB-INF/app/', exclude: %w[ views/ ])
O.copy_dir!('lib', 'WEB-INF/lib/')

O.copy_dir!('flor', 'WEB-INF/flor/') # too specific...

O.copy_config_ru!

O.copy_gems!
O.move_jars!

O.manifest!
O.jar!

