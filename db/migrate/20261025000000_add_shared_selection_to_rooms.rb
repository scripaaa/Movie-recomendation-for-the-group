class AddSharedSelectionToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :selection_filters, :json, default: {}, null: false
    add_column :rooms, :selection_results, :json, default: [], null: false
    add_column :rooms, :selection_generated_at, :datetime
  end
end
