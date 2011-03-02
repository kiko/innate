#          Copyright (c) 2009 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

require File.expand_path('../../../../spec/helper', __FILE__)

# Ignore this test on Mac OS X
spec_precondition 'User isn\'t running Mac OS X' do
  if RUBY_PLATFORM.include? 'darwin'
    should.flunk "Localmemcache doesn't work on Mac OS X and thus this test will be ignored."
  else
    spec_require 'localmemcache'
  end
end

describe Ramaze::Cache::LocalMemCache do
  Ramaze.options.cache.names = [:one, :two]
  Ramaze.options.cache.default = Ramaze::Cache::LocalMemCache
  Ramaze.setup_dependencies

  cache = Ramaze::Cache.one
  hello = 'Hello, World!'

  should 'store without ttl' do
    cache.store(:hello, hello).should.equal hello
  end

  should 'fetch' do
    cache.fetch(:hello).should.equal hello
  end

  should 'delete' do
    cache.delete(:hello)
    cache.fetch(:hello).should.equal nil
  end

  should 'delete two key/value pairs at once' do
    cache.store(:hello, hello).should.equal hello
    cache.store(:ramaze, 'ramaze').should.equal 'ramaze'
    cache.delete(:hello, :ramaze)
    cache.fetch(:hello).should.equal nil
    cache.fetch(:innate).should.equal nil
  end

  should 'store with ttl' do
    cache.store(:hello, @hello, :ttl => 0.2)
    cache.fetch(:hello).should.equal @hello
    sleep 0.3
    cache.fetch(:hello).should.equal nil
  end

  should 'clear' do
    cache.store(:hello, @hello)
    cache.fetch(:hello).should.equal @hello
    cache.clear
    cache.fetch(:hello).should.equal nil
  end
end
