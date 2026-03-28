class CreatePublishLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :publish_logs do |t|
      t.string :filename, null: false
      t.string :title
      t.string :status, null: false
      t.json :platforms, null: false, default: []
      t.json :results, null: false, default: {}
      t.json :publish_errors, default: {}
      t.string :destination_path
      t.datetime :published_at

      t.timestamps
    end

    add_index :publish_logs, :filename
    add_index :publish_logs, :status
    add_index :publish_logs, :published_at
  end
end
