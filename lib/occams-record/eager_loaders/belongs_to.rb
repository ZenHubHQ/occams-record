module OccamsRecord
  module EagerLoaders
    # Eager loader for belongs_to associations.
    class BelongsTo < Base
      #
      # Yield one or more ActiveRecord::Relation objects to a given block.
      #
      # @param rows [Array<OccamsRecord::ResultRow>] Array of rows used to calculate the query.
      #
      def query(rows)
        ids = rows.map { |r| r.send @ref.foreign_key }.compact.uniq
        yield base_scope.where(@ref.active_record_primary_key => ids)
      end

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::ResultRow>] rows loaded from the association
      # @param rows [Array<OccamsRecord::ResultRow>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        Merge.new(rows, name).
          single!(assoc_rows, @ref.foreign_key.to_s, @model.primary_key.to_s)
      end
    end
  end
end
