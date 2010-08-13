# coding:utf-8
# vi:set ts=3 sw=3:
# vim:set sts=0 noet:

# by Nobuyoshi Nakada [ruby-dev:41909]

class Loop
	def loop
		begin
			t, val = catch(self){
				yield self
				true
			}
		end while t
		val
	end

	def next val=nil
		throw self, [true, val]
	end

	def break val=nil
		throw self, [false, val]
	end

	def self.loop &block
		new.loop(&block)
	end

	private

	def self.new
		super
	end
end
