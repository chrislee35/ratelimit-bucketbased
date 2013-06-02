require "ratelimit/bucketbased/version"

module RateLimit
	# Bucket tracks the credits for each item.
	# Each bucket has the following parameters:
	# * *Args*    :
	#   - +name+ -> the name of the item that you allocated the bucket for
	#   - +current+ -> the current credit limit (which may be larger than max, or more negative than min)
	#   - +max+ -> the maximum that the bucket will be filled by the regeneration process
	#   - +min+ -> the minimum that a bucket can go, must be <= 0.
	#   - +refill_amount+ -> the amount that will be added to the bucket every refill_epoch seconds.
	#   - +refill_epoch+ -> the number of seconds before the bucket is credited by the regeneration process
	#   - +last_refill+ -> the timestamp of the last refill
	#   - +total_used+ -> the total, cumulative credits used for service (so refusals don't count)
  # * *Returns* :
  #   - a Bucket
  
	class Bucket < Struct.new(:name, :current, :max, :min, :cost, :refill_amount, :refill_epoch, :last_refill, :total_used); end
	# To set bucket parameters easily, you can create named configurations to create buckets using those templates.  
	# The configurations have the following parameters:
	# * <tt>name</tt>:: the name of the configuration
	# * <tt>start</tt>:: the credits that a new bucket starts with
	# * <tt>max</tt>:: the maximum that the bucket will be filled by the regeneration process
	# * <tt>min</tt>:: the minimum that a bucket can go, must be <= 0.
	# * <tt>refill_amount</tt>:: the amount that will be added to the bucket every refill_epoch seconds.
	# * <tt>refill_epoch</tt>:: the number of seconds before the bucket is credited by the regeneration process
	class Config < Struct.new(:name, :start, :max, :min, :cost, :refill_amount, :refill_epoch); end
	
	# "Storage" is a jerk class that throws exceptions if you forgot to implement a critical function, welcome to Ruby (no interface)
	# Bucket tracks the credits for each item.
	# Each bucket has the following parameters:
	# * *Args*    :
	#   - +name+ -> the name of the item that you allocated the bucket for
	#   - +current+ -> the current credit limit (which may be larger than max, or more negative than min)
	#   - +max+ -> the maximum that the bucket will be filled by the regeneration process
	#   - +min+ -> the minimum that a bucket can go, must be <= 0.
	#   - +refill_amount+ -> the amount that will be added to the bucket every refill_epoch seconds.
	#   - +refill_epoch+ -> the number of seconds before the bucket is credited by the regeneration process
	#   - +last_refill+ -> the timestamp of the last refill
	#   - +total_used+ -> the total, cumulative credits used for service (so refusals don't count)
  # * *Returns* :
  #   - a Bucket
  # * *Raises* :
  #   - +ArgumentError+ -> if any value is nil or negative
	class Storage
		# retrieves a named bucket
		# * *Args*    :
		#   - +name+ -> the name of the bucket to be retrieved
		# * *Returns* :
		#   - the bucket matching the name if found, nil otherwise
		# * *Raises* :
		#   - +NoMethodError+ -> always, because this class is a jerk
		def get(name)
			raise NoMethodError
		end
		
		# saves a bucket into the storage
		# * *Args*    :
		#   - +bucket+ -> the Bucket to set.  The <tt>name</tt> field in the Bucket option will be used as a key.
		# * *Returns* :
		#   - nil
		# * *Raises* :
		#   - +NoMethodError+ -> always, because this class is a jerk
		def set(bucket)
			raise NoMethodError
		end

		# updates the key fields that need updating into the storage
		# this is often cheaper for certain types of storage than using set()
		# * *Args*    :
		#   - +bucket+ -> the Bucket to update.  The <tt>name</tt> field in the Bucket option will be used as a key.
		# * *Returns* :
		#   - nil
		# * *Raises* :
		#   - +NoMethodError+ -> always, because this class is a jerk
		def update(bucket)
			raise NoMethodError
		end
	end
	
	class Memory < Storage
		def initialize
			@buckets = {}
		end
		
		# retrieves a named bucket
		# * *Args*    :
		#   - +name+ -> the name of the bucket to be retrieved
		# * *Returns* :
		#   - the bucket matching the name if found, nil otherwise
		def get(name)
			@buckets[name]
		end
		
		# saves a bucket into the storage
		# * *Args*    :
		#   - +bucket+ -> the Bucket to set.  The <tt>name</tt> field in the Bucket option will be used as a key.
		# * *Returns* :
		#   - the bucket that is provided in the Args
		def set(bucket)
			@buckets[bucket.name] = bucket
		end
		
		# updates the key fields that need updating into the storage
		# this is often cheaper for certain types of storage than using set()
		# * *Args*    :
		#   - +bucket+ -> the Bucket to update.  The <tt>name</tt> field in the Bucket option will be used as a key.
		# * *Returns* :
		#   - nil
		def update(bucket)
			# already updated
		end
	end
	
	class MySQL < Storage
		def initialize(dbh, table, fields=["name","current","max","min","cost","refill_amount","refill_epoch","last_refill","total_used"])
			@queries = {
				'get' => dbh.prepare("SELECT `#{fields.join('`, `')}` FROM `#{table}` WHERE `#{fields[0]}` = ? LIMIT 1"),
				'update' => dbh.prepare("UPDATE `#{table}` SET `#{fields[1]}` = ?, `#{fields[7]}` = ?, `#{fields[8]}` = ? WHERE `#{fields[0]}` = ?"),
				'set' => dbh.prepare("REPLACE INTO `#{table}` (`#{fields.join('`, `')}`) VALUES (?,?,?,?,?,?,?,?,?)")
			}
		end
		
		# retrieves a named bucket
		# * *Args*    :
		#   - +name+ -> the name of the bucket to be retrieved
		# * *Returns* :
		#   - the bucket matching the name if found, nil otherwise
		# * *Raises* :
		#   - +Mysql::Error+ -> any issue with the connection to the database or the SQL statements
		def get(name)
			rs = @queries['get'].execute(name)
			bucket = nil
			rs.each do |row|
				bucket = Bucket.new(row[0],*row[1,8].map{|x| x.to_f})
			end
			bucket
		end
		
		# saves a bucket into the storage
		# * *Args*    :
		#   - +bucket+ -> the Bucket to set.  The <tt>name</tt> field in the Bucket option will be used as a key.
		# * *Returns* :
		#   - an empty result set
		# * *Raises* :
		#   - +Mysql::Error+ -> any issue with the connection to the database or the SQL statements
		def set(bucket)
			@queries['set'].execute(bucket.name, bucket.current, bucket.max, bucket.min, bucket.cost, bucket.refill_amount, bucket.refill_epoch, bucket.last_refill, bucket.total_used)
		end
		
		# updates the key fields that need updating into the storage
		# this is often cheaper for certain types of storage than using set()
		# * *Args*    :
		#   - +bucket+ -> the Bucket to update.  The <tt>name</tt> field in the Bucket option will be used as a key.
		# * *Returns* :
		#   - an empty result set
		# * *Raises* :
		#   - +Mysql::Error+ -> any issue with the connection to the database or the SQL statements
		def update(bucket)
			@queries['update'].execute(bucket.current, bucket.last_refill, bucket.total_used, bucket.name)
		end
	end
	
	SQLite3 = MySQL
	
	class MemCache
		def initialize(cache_handle)
			@cache = cache_handle
		end
		
		# retrieves a named bucket
		# * *Args*    :
		#   - +name+ -> the name of the bucket to be retrieved
		# * *Returns* :
		#   - the bucket matching the name if found, nil otherwise
		def get(name)
			value = @cache.get(name)
			return nil unless value
			row = value.split(/\|/)
			bucket = nil
			if row
				bucket = Bucket.new(row[0],*row[1,8].map{|x| x.to_f})
			end
			bucket
		end
		
		# saves a bucket into the storage
		# * *Args*    :
		#   - +bucket+ -> the Bucket to set.  The <tt>name</tt> field in the Bucket option will be used as a key.
		# * *Returns* :
		#   - the bucket that is provided in the Args
		def set(bucket)
			@cache.set(bucket.name,bucket.values.join("|"))
		end
		
		alias :update :set
	end
	
	Memcache = MemCache
	Redis = MemCache
	
	# BucketBased is the star of the show.  It takes a storage, a set of configurations, and the name of the default configuration.
	# <tt>storage</tt>:: a method for saving and retrieving buckets (memory, mysql, sqlite3, memcache)
	# <tt>bucket_configs</tt>:: a hash of name => Config pairs
	# <tt>default_bucket_config</tt>:: the name of the default config to choose when automatically creating buckets for items that don't have buckets
	class BucketBased
		attr_reader :storage
		def initialize(storage, bucket_configs, default_bucket_config='default')
			@storage = storage
			@bucket_configs = bucket_configs
			if @bucket_configs.keys.length == 1
				@default_bucket_config =  @bucket_configs.keys[0]
			else
				@default_bucket_config = default_bucket_config
			end
			raise "Cannot find default config" unless @bucket_configs[@default_bucket_config]
		end

		# Used primarily to preallocate buckets that need an alternate configuration from the default so that they aren't automatically created with default configurations
		# <tt>name</tt>:: the name of the item to track
		# <tt>config_name</tt>:: the name of the config to use as a template for creating the bucket
		# The new bucket will be saved into the storage for this instance of RateLimiter
		def create_bucket(name, config_name=@default_bucket_config)
			config = @bucket_configs[config_name]
			raise "Config is nil" unless config
			bucket = Bucket.new(name, config.start, config.max, config.min, config.cost, config.refill_amount, config.refill_epoch, Time.now.to_f, 0.0)
			@storage.set(bucket)
		end
		
		# Returns <i>true</i> if the item <tt>name</tt> has enough credits, <i>false</i> otherwise
		# It will automatically create buckets for items that don't already have buckets and it will do all the bookkeeping to deduct credits, regenerate credits, and track all the credits used.
		# <tt>name</tt>:: the name of the item to track
		# <tt>cost</tt>:: the cost of the transaction (defaults to the cost set in the Bucket if nil)
		def use(name, cost=nil)
			# create a bucket using the default config if it doesn't already exist
			bkt = @storage.get(name)
			unless bkt
				create_bucket(name)
				bkt = @storage.get(name)
			end
			unless bkt
				raise Exception, "Could not find bucket"
			end
			# first credit the bucket for the time that has elapsed
			epochs_elapsed = ((Time.now.to_f - bkt.last_refill)/bkt.refill_epoch).to_i
			bkt.current += epochs_elapsed * bkt.refill_amount
			bkt.current = bkt.max if bkt.current > bkt.max
			bkt.last_refill += epochs_elapsed*bkt.refill_epoch
			# now see if the bkt has enough to provide service
			cost ||= bkt.cost # if the cost isn't provided, use the default cost
			raise "Invalid cost: #{cost}" if cost < 0
			enough = bkt.current >= cost # true if sufficient, false if insufficient
			# track the total costs, but only if service will be rendered
			bkt.total_used += cost if enough
			# now deduct the cost, capping at the minimum
			bkt.current -= cost
			bkt.current = bkt.min if bkt.current < bkt.min
			# now save the changes into the storage (if memory, then no changes are needed, we updated the object in memory)
			@storage.update(bkt)
			# return the verdict, did they have enough credits to pay the toll?
			enough
		end
	end
end
