
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
	cd $(JRACK)_jar && jar cvf ../$(JRACK).jar .


.PHONY: clean

