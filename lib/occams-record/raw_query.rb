module OccamsRecord
  #
  # Starts building a OccamsRecord::RawQuery. Pass it a raw SQL statement, optionally followed by
  # a Hash of binds.
  #
  #   results = OccamsRecord.sql(%(
  #     SELECT * FROM widgets
  #     WHERE category_id = %{cat_id}
  #   ), {
  #     cat_id: 5
  #   }).run
  #
  # If you want to do eager loading, you must first the define a model to pull the associations from.
  #
  #   results = OccamsRecord.
  #     sql(%(
  #       SELECT * FROM widgets
  #       WHERE category_id = %{cat_id}
  #     ), {
  #       cat_id: 5
  #     }).
  #     model(Widget).
  #     eager_load(:category).
  #     run
  #
  # @param sql [String] The SELECT statement to run. Binds should use the built-in Ruby "%{bind_name}" syntax.
  # @param binds [Hash] Bind values (Symbol keys)
  # @param use [Array<Module>] optional Module to include in the result class (single or array)
  # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
  # @return [OccamsRecord::RawQuery]
  #
  def self.sql(sql, binds, use: nil, query_logger: nil)
    RawQuery.new(sql, binds, use: use, query_logger: nil)
  end

  #
  # Represents a raw SQL query to be run and eager associations to be loaded. Use OccamsRecord.sql to create your queries
  # instead of instantiating objects directly.
  #
  class RawQuery
    # @return [String]
    attr_reader :sql
    # @return [Hash]
    attr_reader :binds

    include EagerLoaders::Builder

    #
    # Initialize a new query.
    #
    # @param sql [String] The SELECT statement to run. Binds should use the built-in Ruby "%{bind_name}" syntax.
    # @param binds [Hash] Bind values (Symbol keys)
    # @param use [Array<Module>] optional Module to include in the result class (single or array)
    # @param eager_loaders [OccamsRecord::EagerLoaders::Base]
    # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
    # @param eval_block [Proc] block that will be eval'd on this instance. Can be used for eager loading. (optional)
    #
    def initialize(sql, binds, use: nil, eager_loaders: [], query_logger: nil)
      @sql = sql
      @binds = binds
      @use = use
      @eager_loaders = eager_loaders
      @query_logger = query_logger
      @model = nil
    end

    #
    # Specify the model to be used to load eager associations. Normally this would be the main table you're
    # SELECTing from.
    #
    # @param klass [ActiveRecord::Base]
    # @return [OccamsRecord::RawQuery] self
    #
    def model(klass)
      @model = klass
      self
    end

    #
    # Run the query and return the results.
    #
    # @return [Array<OccamsRecord::Results::Row>]
    #
    def run
      conn = @model&.connection || ActiveRecord::Base.connection
      escaped_sql = sql % binds.reduce({}) { |a, (col, val)|
        a[col.to_sym] = conn.quote val
        a
      }
      result = conn.exec_query escaped_sql
      row_class = OccamsRecord::Results.klass(result.columns, result.column_types, @eager_loaders.map(&:name), model: @model, modules: @use)
      rows = result.rows.map { |row| row_class.new row }
      eager_load! rows
      rows
    end

    alias_method :to_a, :run

    #
    # If you pass a block, each result row will be yielded to it. If you don't,
    # an Enumerable will be returned.
    #
    # @return Enumerable
    #
    def each
      if block_given?
        to_a.each { |row| yield row }
      else
        to_a.each
      end
    end
  end
end
