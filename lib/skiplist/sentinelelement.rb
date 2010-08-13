# coding:utf-8
# vi:set ts=3 sw=3:
# vim:set sts=0 noet:

=begin
Copyright (c) 2010 KISHIMOTO, Makoto

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
=end

class SentinelElement
	include Comparable

	MAX = new
	MIN = new

	private

	def self.new
		super
	end
end

class << SentinelElement::MAX
	def <=> other
		if equal? other then
			0
		else
			1
		end
	end

	def coerce other
		[MIN, self]
	end
end

class << SentinelElement::MIN
	def <=> other
		if equal? other then
			0
		else
			-1
		end
	end

	def coerce other
		[MAX, self]
	end
end
