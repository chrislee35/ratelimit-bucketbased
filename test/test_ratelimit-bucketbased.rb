unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'helper'

def get_configs
	# set up the configs
	start = max = 5
	min = -5
	cost = refill_amount = refill_epoch = 1
	configs = { 
		'default' => RateLimit::Config.new('default', start, max, min, cost, refill_amount, refill_epoch),
		'power' => RateLimit::Config.new('default', 10, 10, min, cost, refill_amount, refill_epoch)
	}
end

def standard_tests(rl)
	# add a bucket named "admin", using a non-default configuration
	rl.create_bucket('admin', 'power')
	0.upto(4) do 
		assert(rl.use("test"))
	end
	0.upto(9) do
		assert(rl.use("admin"))
	end
	assert(! rl.use("test"))
	assert(! rl.use("admin"))
	# should be at -2, need two epochs to have enough to do another hit
	sleep 2
	assert(rl.use("test"))
	assert(rl.use("admin"))
	assert_equal(6,rl.storage.get("test").total_used)
	assert_equal(11,rl.storage.get("admin").total_used)
end

class TestRateLimitBucketBased < Test::Unit::TestCase
	
	
	def test_setup_a_rate_limiter_and_work_five_times_before_exhaution
		#should "setup a rate limiter and work five times before exhaution" do
		# create a Memory-based storage
		storage = RateLimit::Memory.new
		# create the rate limiter, setting the storage, the configurations, and the name of the default configuration
		rl = RateLimit::BucketBased.new(storage, get_configs, 'default')
		# run the standard tests
		standard_tests(rl)
	end

	def test_raise_an_exception_with_a_cost_of_less_than_0
		#should "raise an exception with a cost of less than 0" do
		# set up the configs
		start = max = 5
		min = -5
		cost = refill_amount = refill_epoch = 1
		configs = { 
			'default' => RateLimit::Config.new('default', start, max, min, cost, refill_amount, refill_epoch),
			'power' => RateLimit::Config.new('default', 10, 10, min, cost, refill_amount, refill_epoch)
		}
		# create a Memory-based storage
		storage = RateLimit::Memory.new
		# create the rate limiter, setting the storage, the configurations, and the name of the default configuration
		rl = RateLimit::BucketBased.new(storage, configs, 'default')
		assert_raise(RuntimeError) {
			rl.use("test",-1)
		}
	end
end

class TestRateLimitBucketBasedSqlite3 < Test::Unit::TestCase
	def cleanup
		File.unlink("test/test.db") if File.exist?("test/test.db")
	end
	
	def test_track_the_changes_in_an_SQLite3_database
		#should "track the changes in an SQLite3 database" do
		# create a SQLite3-based storage: first create the database, then the table, then the storage
		File.unlink("test/test.db") if File.exist?("test/test.db")
		dbh = SQLite3::Database.new( "test/test.db" )
		assert_not_nil(dbh)
		res = dbh.execute("CREATE TABLE users (`name`,`current`,`max`,`min`,`cost`,`refill_amount`,`refill_epoch`,`last_refill`,`total_used`,primary key (`name`))")
		assert(res)
		storage = RateLimit::SQLite3.new(dbh,'users')
	
		# create the rate limiter, setting the storage, the configurations, and the name of the default configuration
		rl = RateLimit::BucketBased.new(storage, get_configs, 'default')
		# run the standard tests
		standard_tests(rl)
	end

	def test_track_the_changes_in_an_SQLite3_database_using_a_custom_field_set
		#should "track the changes in an SQLite3 database using a custom field-set" do
		# create a SQLite3-based storage: first create the database, then the table, then the storage
		File.unlink("test/test.db") if File.exist?("test/test.db")
		dbh = SQLite3::Database.new( "test/test.db" )
		assert_not_nil(dbh)
		fields = ["username","credits","max_credits","min_credits","cost_per_transaction","refill_credits","refill_seconds","last_refill_time","total_used_credits"]
		res = dbh.execute("CREATE TABLE users (`#{fields.join('`, `')}`,primary key (`username`))")
		assert(res)
		storage = RateLimit::SQLite3.new(dbh,'users',fields)
	
		# create the rate limiter, setting the storage, the configurations, and the name of the default configuration
		rl = RateLimit::BucketBased.new(storage, get_configs, 'default')
		# run the standard tests
		standard_tests(rl)
	end
end

class TestRateLimitBucketBasedMemcache < Test::Unit::TestCase
	def setup
		# create a MemCache-based storage
		memcache = Memcache.new(:server => 'localhost:11211')
		memcache.delete("test")
		memcache.delete("admin")
	end
	
	def test_track_the_changes_in_memcache
		#should "track the changes in memcache" do
		# create a MemCache-based storage
		memcache = Memcache.new(:server => 'localhost:11211')
		assert_not_nil(memcache)
		storage = RateLimit::Memcache.new(memcache)
	
		# create the rate limiter, setting the storage, the configurations, and the name of the default configuration
		rl = RateLimit::BucketBased.new(storage, get_configs, 'default')
		# run the standard tests
		standard_tests(rl)
	end
end
	
class TestRateLimitBucketBasedRedis < Test::Unit::TestCase
	def setup
		# remove stale entries that could conflict with our test
		redis = Redis.new(:server => 'localhost', :port => 6379)
		redis.del("test")
		redis.del("admin")
	end
	
	def test_track_the_changes_in_redis
		#should "track the changes in redis" do
		# create a Redis-based storage
		redis = Redis.new(:server => 'localhost', :port => 6379)
		assert_not_nil(redis)
		storage = RateLimit::Redis.new(redis)
	
		# create the rate limiter, setting the storage, the configurations, and the name of the default configuration
		rl = RateLimit::BucketBased.new(storage, get_configs, 'default')
		# run the standard tests
		standard_tests(rl)
	end
end