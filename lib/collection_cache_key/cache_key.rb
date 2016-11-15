module CollectionCacheKey
  module CacheKey
    def collection_cache_key(collection = as_default_relation,
                             timestamp_column = :updated_at) # :nodoc:

      key, size, timestamp = details_for(collection, timestamp_column)

      return "#{key}-#{size}" unless timestamp
      "#{key}-#{size}-#{time_to_string(timestamp)}"
    end

    unless respond_to?(:cache_timestamp_format)
      def cache_timestamp_format
        :nsec
      end
    end

    private

    def as_default_relation
      where '1 = 1'
    end

    def details_for(collection, timestamp_column)
      column = "#{connection.quote_table_name(collection.table_name)}.#{connection.quote_column_name(timestamp_column)}"
      query = collection
        .unscope(:select)
        .select("COUNT(*) AS #{connection.quote_column_name('size')}", "MAX(#{column}) AS timestamp")
        .unscope(:order)
        .unscope(:limit)
        .unscope(:offset)
      result = connection.select_one(query)

      if result.blank?
        size = 0
        timestamp = nil
      else
        size = result['size']
        timestamp = parsed_timestamp(attrs['timestamp'])
      end

      [query_key(collection), size, timestamp]
    end

    def query_key(collection)
      "#{collection.model_name.cache_key}/query-#{query_signature(collection)}"
    end

    def query_signature(collection)
      Digest::MD5.hexdigest(collection.to_sql.gsub(/ +/, ' '))
    end

    def parsed_timestamp(value)
      if ActiveRecord.stores_local_time?
        Time.parse(value.to_s).utc
      else
        Time.use_zone('UTC') { Time.zone.parse(value.to_s) }
      end
    rescue ArgumentError
      nil
    end

    def time_to_string(timestamp)
      if cache_timestamp_format == :nsec
        timestamp.strftime('%Y%m%d%H%M%S%9N')
      else
        timestamp.to_s(cache_timestamp_format)
      end
    end
  end
end
