# coding:utf-8
# vi:set ts=3 sw=3:
# vim:set sts=0 noet:

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require "skiplist/loop"
require "skiplist/sentinelelement"
require "skiplist/skiplist_mlink"

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

#
#= Lock-Free Skip List
#
#Authors::   KISHIMOTO, Makoto
#Version::   0.0.2 2010-Aug-13
#Copyright:: Copyright (c) 2010 KISHIMOTO, Makoto
#License::   (other than loop.rb ) X License
#
#=== References
#
#- The Art of Multiprocessor Programming, Chap. 14
#
class SkipList
	VERSION = '0.0.2'

	#
	# Node of SkipList, inner use only
	#
	class Node
		attr_accessor :toplevel, :key, :val

		def initialize toplevel, key, val
			@toplevel = toplevel
			@key = key
			@val = val
			@links = Array.new(@toplevel + 1)
		end

		def print_debug
			puts "object_id = 0x%014x" % [object_id]
			puts "@toplevel = #{@toplevel}"
			puts "@key = #{@key}"
			puts "@val = #{@val}"
			puts "@links = "
			@links.each_index{|i|
				print "[#{i}] "
				@links[i].print_debug
			}
		end

		def [] level
			@links[level]
		end

		def []= level, node
			@links[level] = node
		end
	end

	attr_reader :size

	#
	# Create a SkipList object.
	#
	# level_max :: If this list will have approximately N elements, you sholud set this log_2 N.
	#
	def initialize level_max, cmp_op=:<=>, max_element=nil
		if level_max < 0 then
			raise ArgumentError.new "level_max must not be negative"
		end
		@level_max = level_max
		@cmp_op = cmp_op
		max = if max_element then max_element else SentinelElement::MAX end
		@tail = Node.new @level_max, max, nil
		(0).upto(@level_max){|i|
			@tail[i] = MLink.new nil
		}
		@head = Node.new @level_max, nil, nil
		(0).upto(@level_max){|i|
			@head[i] = MLink.new @tail
		}
		@randgen = Random.new
		@size_lock = Mutex.new
		@size = 0
	end

	# for debug use
	def print_debug
		puts "@level_max = #{@level_max}"
		puts "@cmp_op = #{@cmp_op}"
		puts "@randgen = #{@randgen}"
		puts "@size = #{@size}"
		puts ""
		puts "Nodes"
		puts ""
		p = @head
		while p do
			p.print_debug
			puts ""
			p = p[0].get_link
		end
	end

	# this returns one of 0..ex, approx of 0 is 1/2, 1 is 1/4, 2 is 1/8, ...
	def rand2exp ex
		mask = 1 << (ex + 1)
		r = 1 + @randgen.rand(mask - 1)
		mask >>= 1
		i = 0
		while r & mask == 0 do
			mask >>= 1
			i += 1
		end
		i
	end
	private :rand2exp

	#
	# call-seq:
	#     lst.empty? -> true or false
	#
	# Returns <code>true</code> if <i>lst</i> contains no elements.
	#
	def empty?
		p = @head[0].get_link
		pp, m = p[0].get
		while m do
			p = pp
			pp, m = p[0].get
		end
		p.equal? @tail
	end

	#
	# call-seq:
	#     lst.to_a -> array
	#
	# Converts <i>lst</i> to a array of <code>[</code> <i>key, value</i>
	# <code>]</code> arrays.
	#
	#     lst = SkipList.new 5
	#     lst["foo"] = 1
	#     lst["bar"] = 2
	#     lst["baz"] = 3
	#     lst.to_a  #=> [["bar", 2], ["baz", 3], ["foo", 1]]
	#
	def to_a
		arr = []
		p, m = @head[0].get
		while p do
			if not m then
				arr.push [p.key, p.val]
			end
			p, m = p[0].get
		end
		arr.pop
		arr
	end

	# for inner use
	def find key, before_list, after_list
		Loop.loop {|tag|
			pp = nil
			p = @head
			@level_max.downto(0){|level|
				pp = p[level].get_link
				loop {
					ppp, mark = pp[level].get
					while mark do
						snip = p[level].compare_and_set pp, ppp, false, false
						unless snip then
							tag.next
						end
						#pp = ppp  # ?
						pp = p[level].get_link
						ppp, mark = pp[level].get
					end
					if pp.key < key then
						p = pp
						pp = ppp
					else
						break
					end
				}
				before_list[level] = p
				after_list[level] = pp
			}
			if pp.key == key then
				tag.break pp
			else
				tag.break nil
			end
		}
	end
	private :find

	#
	# call-seq:
	#     lst[key] = val -> val
	#
	# Insert new node that key is <i>key</i> and value is <i>val</i>.
	# If already exist the node with key == <i>key</i>, assign new <i>val</i>.
	# This method returns <i>val</i>.
	#
	#     lst = SkipList.new 5
	#     lst["foo"] = 1
	#     lst["bar"] = 2
	#     lst["baz"] = 3
	#     lst.to_a  #=> [["bar", 2], ["baz", 3], ["foo", 1]]
	#
	def []= key, val
		before_list = Array.new(@level_max + 1)
		after_list = Array.new(@level_max + 1)
		loop {
			if p = find(key, before_list, after_list) then
				p.val = val
				break
			end
			toplevel = rand2exp @level_max
			node = Node.new toplevel, key, val
			(0).upto(toplevel){|level|
				node[level] = MLink.new after_list[level]
			}
			unless before_list[0][0].compare_and_set after_list[0], node, false, false then
				next
			end
			@size_lock.synchronize {
				@size += 1
			}
			(1).upto(toplevel){|level|
				loop {
					if before_list[level][level].compare_and_set after_list[level], node, false, false then
						break
					end
					find key, before_list, after_list
				}
			}
			break
		}
		val
	end

	#
	# call-seq:
	#     lst[key] -> value
	#
	# Element reference. 
	#
	#     lst = SkipList.new 5
	#     lst["foo"] = 1
	#     lst["bar"] = 2
	#     lst["baz"] = 3
	#     lst["foo"]  #=> 1
	#     lst["bar"]  #=> 2
	#     lst["baz"]  #=> 3
	#
	def [] key
		pp = nil
		p = @head
		@level_max.downto(0){|level|
			pp = p[level].get_link  # ?
			loop {
				ppp, mark = pp[level].get
				while mark do
					#pp = ppp  # ?
					pp = pp[level].get_link
					ppp, mark = pp[level].get
				end
				if pp.key < key then
					p = pp
					pp = ppp
				else
					break
				end
			}
		}
		if pp.key == key then
			pp.val
		else
			nil
		end
	end

	#
	# call-seq:
	#     lst.delete[key] -> value
	#
	# Element deletion. Returns a value of deleted element.
	#
	#     lst = SkipList.new 5
	#     lst["foo"] = 1
	#     lst["foo"]  #=> 1
	#     lst.delete["foo"]  #=> 1
	#     lst["foo"]  #=> nil
	#     lst.delete["bar"]  #=> nil
	#
	def delete key
		before_list = Array.new(@level_max + 1)
		after_list = Array.new(@level_max + 1)
		unless p = find(key, before_list, after_list) then
			return nil
		end
		p.toplevel.downto(1){|level|
			pp, mark = p[level].get
			until mark do
				p[level].compare_and_set pp, pp, false, true
				pp, mark = p[level].get
			end
		}
		pp, mark = p[0].get
		loop {
			i_marked_it = p[0].compare_and_set pp, pp, false, true
			pp, mark = p[0].get
			if i_marked_it then
				@size_lock.synchronize {
					@size -= 1
				}
				#find key, before_list, after_list
				break p.val
			elsif mark then
				break nil
			end
		}
	end
end

#

if $0 == __FILE__ then
	puts "------------------------"
	list = SkipList.new 5
	list["foo"] = "foo"
	list["bar"] = "bar"
	list["baz"] = "baz"
	list.print_debug
	puts "------------------------"
	list = SkipList.new 5
	list["foo"] = "foo"
	list["bar"] = "bar"
	list["baz"] = "baz"
	list.delete "foo"
	list.print_debug
	puts "------------------------"
	list = SkipList.new 5
	list["foo"] = "foo"
	list["bar"] = "bar"
	list["baz"] = "baz"
	list.delete "bar"
	list.print_debug
	puts "------------------------"
	list = SkipList.new 5
	list["foo"] = "foo"
	list["bar"] = "bar"
	list["baz"] = "baz"
	list.delete "baz"
	list.print_debug
	puts "------------------------"
end
