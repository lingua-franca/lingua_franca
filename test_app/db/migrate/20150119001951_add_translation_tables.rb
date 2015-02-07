
class AddTranslationTables < ActiveRecord::Migration
  def change
    create_table :translation_records do |t|
      #t.integer :id
      t.string :locale
      t.integer :translator_id
      t.string :key
      t.text :value
      t.datetime :created_at
    end

    create_table :dynamic_translation_records do |t|
      #t.integer :id
      t.string :locale
      t.integer :translator_id
      t.string :model_type
      t.integer :model_id
      t.string :column
      t.text :value
      t.datetime :created_at
    end
  end
end
