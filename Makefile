
JRACK = jruby-rack-1.1.22


clean:
	rm -fR war_*
	rm -f *.war

jrack:
	rm -f jruby-rack*.gem
	rm -fR jruby-rack*_jar
	wget https://rubygems.org/downloads/$(JRACK).gem
	gem unpack $(JRACK).gem
	mkdir $(JRACK)_jar
	cd $(JRACK)_jar && jar xvf ../$(JRACK)/lib/$(JRACK).jar
	rm -fR $(JRACK)_jar/vendor/
	echo 'require "pp"; puts "+" * 80; puts __FILE__; pp ENV; puts "+" * 80; Gem.paths=(ENV) # warmaker.rb ;-)' | \
      cat - $(JRACK)_jar/jruby/rack/rack_ext.rb > tmp.rb
	mv tmp.rb $(JRACK)_jar/jruby/rack/rack_ext.rb
	cd $(JRACK)_jar && jar cvf ../$(JRACK).jar .


.PHONY: jrack clean

