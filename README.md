# RateLimit::BucketBased

This is a very simple rate limiting gem useful for regulating the speed at which service is provided and denying service when that rate has been exceeded.  This is very similar to other gems like ratelimit, rack-ratelimiter, rate-limiting, and a ton of gems with the name "throttle" in them.  Mine is different in that it (a) isn't tied to a particular storage, (b) isn't tied to a particular framework, and (c) was written by me.  I guess there might be merits to my approach, but there's a lot of sharp coders out there.

To track the rates of various transactions Memory, MySQL, SQLite3, MemCache, and Redis storage options are supported, but the appropriateness of one over another for various workloads is an exercise left to the reader. I have not added any crafty speed-ups for the SQL databases (e.g., dynamically sized bloom filters), so use those primarily for durability and scalability, not high transaction rates.  Probably the only solution that can scale in the number of items it can track, handle high-transaction loads, and have some durability is Redis.  (it's too bad that MemCache can't save to disk)

Tested in ruby-1.8.7-p371, ruby-1.9.3-p392, and ruby-2.0.0-p0.
The Memcache gem fails to compile in ruby-2.0.

### The Concept

Imagine a set of buckets, one for each item you want to rate limit such as a user, an apikey, or answers to queries, with a number of balls (credits) in each bucket.  Whenever a service is used, balls (credits) are removed from the user's bucket.  When the user has no more credits left, the service is denied.  Credits are added back to the bucket over time, up to a maximum.  It is also possible for someone to be denied service, but since they keep asking for it anyway, they can go into debt up to a minimum (a negative number), thus they will have to wait some time to let the debt be paid.

Thus, each bucket has the following properties:
* +name+: the name of the item that you allocated the bucket for
* +current+: the current credit limit (which may be larger than max, or more negative than min)
* +max+: the maximum that the bucket will be filled by the regeneration process
* +min+: the minimum that a bucket can go, must be <= 0.
* +refill_amount+: the amount that will be added to the bucket every refill_epoch seconds.
* +refill_epoch+: the number of seconds before the bucket is credited by the regeneration process
* +last_refill+: the timestamp of the last refill
* +total_used+: the total, cumulative credits used for service (i.e., refusals don't count)

To set these parameters easily, you can create named configurations to create buckets using those templates.  The configurations have the following fields:
* +name+: the name of the configuration
* +start+: the credits that a new bucket starts with
* +max+: the maximum that the bucket will be filled by the regeneration process
* +min+: the minimum that a bucket can go, must be <= 0.
* +refill_amount+: the amount that will be added to the bucket every refill_epoch seconds.
* +refill_epoch+: the number of seconds before the bucket is credited by the regeneration process


## Installation

Add this line to your application's Gemfile:

    gem 'ratelimiter-bucketbased'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ratelimiter-bucketbased

## Usage

The steps to use the rate limiter are the following:
1. set up the configurations for accounting, 
1. create a store, (currently, Memory, MySQL, SQLite3, MemCache, and Redis storage options are supported)
1. create the rate limiter, 
1. add non-default items, 
1. and provide service.

For each of the examples below, use the following template:

	require 'ratelimit-bucketbased'

	# set up the configs
	start = max = 10
	min = -10
	cost = refill_amount = refill_epoch = 2
	configs = { 
	  'default' => RateLimit::Config.new('default', start, max, min, cost, refill_amount, refill_epoch),
	  'power' => RateLimit::Config.new('default', 20, 20, min, cost, refill_amount, 1)
	}

	# create a store
	*storage creation code here, see sub-sections below*

	# create the rate limiter, setting the storage, the configurations, and the name of the default configuration
	rl = RateLimit::BucketBased.new(storage, configs, 'default')
	# add a bucket named "admin", using a non-default configuration
	rl.create_bucket('admin', 'power')

	def provide_service(username)
	  if rl.use(username)
	    // perform service
	  end
	end

### Memory-based Store

	# create a Memory-based storage
	storage = RateLimit::Memory.new

### SQLite3-based Store

	require 'sqlite3'

	# attach to a SQLite3-based storage
	dbh = SQLite3::Database.new( "test/test.db" )
	custom_fields = ["username","credits","max_credits","min_credits","cost_per_transaction","refill_credits","refill_seconds","last_refill_time","total_used_credits"]
	storage = RateLimit::SQLite3.new(dbh,'users_table',custom_fields)

### Memcache-based Store

	require 'memcache'

	# create a MemCache-based storage
	memcache = Memcache.new(:server => 'localhost:11211')
	storage = RateLimit::Memcache.new(memcache)

### Redis-based Store

	require 'redis'

	# create a Redis-based storage
	redis = Redis.new(:server => 'localhost', :port => 6379)
	storage = RateLimit::Redis.new(redis)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
