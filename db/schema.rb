# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_28_090839) do
  create_table "publish_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination_path"
    t.string "filename", null: false
    t.json "platforms", default: [], null: false
    t.json "publish_errors", default: {}
    t.datetime "published_at"
    t.json "results", default: {}, null: false
    t.string "status", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["filename"], name: "index_publish_logs_on_filename"
    t.index ["published_at"], name: "index_publish_logs_on_published_at"
    t.index ["status"], name: "index_publish_logs_on_status"
  end
end
