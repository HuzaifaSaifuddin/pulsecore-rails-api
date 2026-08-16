class ApplicationSerializer
  def self.render_collection(records)
    records.map { |record| new(record).as_json }
  end
end
